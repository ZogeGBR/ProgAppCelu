// Rutas HTTP del backend de FreshMarket.
import crypto from 'node:crypto';

import express from 'express';

import { abrirBd } from './bd.js';
import {
  actualizarProducto,
  agregarProducto,
  ErrorDeValidacion,
  eliminarProducto,
  listarProductos,
} from './catalogo.js';
import { armarEtiqueta } from './ia.js';
import {
  buscarPedido,
  consultarEstado,
  crearClienteMercadoPago,
  crearPreferencia,
  firmaValida,
  marcarPago,
  pedidosParaRepartir,
  procesarWebhook,
} from './pagos.js';
import { marcarEntregado, registrarPosicion, seguimientoDe } from './seguimiento.js';
import { crearCorreo } from './correo.js';
import { crearGeocodificador } from './geo.js';
import { confirmarCodigo, solicitarCodigo } from './recuperacion.js';
import { anotarParaPedido, anotarParaRol, conectarAvisos, olvidarCuenta, tokenValido } from './avisos.js';
import { reiniciarEventos } from './eventos.js';
import { pushEnConsola } from './push.js';
import { crearLimitadorDeIntentos, crearToken, exigirRol } from './sesiones.js';
import { asegurarUsuario, verificarCredenciales } from './usuarios.js';

export function crearApp(config = {}) {
  const {
    mpAccessToken,
    mpSandbox = false,
    mpWebhookSecret,
    geminiApiKey,
    geminiModelo = 'gemini-2.5-flash',
    urlPublica,
    usuariosIniciales = [],
    rutaBd,
    smtpUrl,
    remitenteCorreo,
    googleMapsApiKey,
    contactoMapas,
    geocodificacion = 'nominatim',
    correo: correoInyectado,
    push = pushEnConsola(),
    secretoSesion = crypto.randomBytes(32).toString('hex'),
    simularReparto = !mpAccessToken,
    funcionesApagadas = [],
  } = config;

  abrirBd(rutaBd);
  for (const usuario of usuariosIniciales) asegurarUsuario(usuario);
  conectarAvisos(reiniciarEventos(), push);

  const correo = correoInyectado ?? crearCorreo({ smtpUrl, remitente: remitenteCorreo });
  const direccionDe = crearGeocodificador({
    modo: geocodificacion,
    googleApiKey: googleMapsApiKey,
    contacto: contactoMapas,
  });

  const clienteMp = crearClienteMercadoPago(mpAccessToken);
  const soloDueno = exigirRol(secretoSesion, 'dueno');
  const soloReparto = exigirRol(secretoSesion, 'repartidor', 'dueno');
  const intentoPermitido = crearLimitadorDeIntentos();
  const pedidoDeCodigoPermitido = crearLimitadorDeIntentos();
  const limitar = (permitido) => (req, res, next) =>
    permitido(req.ip)
      ? next()
      : res.status(429).json({ error: 'Demasiados intentos. Esperá un minuto.' });
  const app = express();
  app.use(express.json({ limit: '8mb' }));

  const urlLocalDe = (req) => urlPublica || `${req.protocol}://${req.get('host')}`;

  // Funciones que se prenden o apagan desde el servidor (la app las lee al
  // abrirse). Ver lib/domain/politicas/politicas.dart.
  const funciones = {
    pagoEnEfectivo: !funcionesApagadas.includes('pagoEnEfectivo'),
    cargaConFoto: !funcionesApagadas.includes('cargaConFoto'),
    recordatorioCarrito: !funcionesApagadas.includes('recordatorioCarrito'),
  };
  app.get('/funciones', (_req, res) => res.json(funciones));

  app.get('/salud', (_req, res) => {
    res.json({
      ok: true,
      mercadoPago: clienteMp ? 'real' : 'simulado',
      ia: geminiApiKey ? 'gemini' : 'simulada',
    });
  });

  // --- Sesiones: el dueño y el repartidor entran con email y contraseña ---
  app.post('/sesiones', limitar(intentoPermitido), (req, res) => {
    const usuario = verificarCredenciales(req.body?.email, req.body?.clave);
    if (!usuario) return res.status(401).json({ error: 'Email o contraseña incorrectos.' });
    return res.status(201).json({
      rol: usuario.rol,
      nombre: usuario.nombre,
      token: crearToken(usuario.rol, secretoSesion),
    });
  });

  // --- Recuperar la contraseña ---
  // Siempre 202: la respuesta no dice si el email tiene cuenta.
  app.post('/recuperacion/solicitar', limitar(pedidoDeCodigoPermitido), async (req, res) => {
    try {
      await solicitarCodigo({ email: req.body?.email, correo, secreto: secretoSesion });
    } catch (error) {
      console.error('No se pudo enviar el código:', error.message);
    }
    res.status(202).json({ ok: true });
  });

  app.post('/recuperacion/confirmar', limitar(intentoPermitido), (req, res, next) => {
    try {
      confirmarCodigo({
        email: req.body?.email,
        codigo: req.body?.codigo,
        claveNueva: req.body?.claveNueva,
        secreto: secretoSesion,
      });
      res.sendStatus(204);
    } catch (error) {
      next(error);
    }
  });

  // --- Mapa: de un punto a "calle y número" ---
  app.get('/geo/inversa', async (req, res, next) => {
    try {
      res.json(await direccionDe(req.query.lat, req.query.lng));
    } catch (error) {
      next(error);
    }
  });

  // --- Catálogo ---
  app.get('/productos', (_req, res) => res.json(listarProductos()));

  app.post('/productos', soloDueno, (req, res, next) => {
    try {
      res.status(201).json(agregarProducto(req.body));
    } catch (error) {
      next(error);
    }
  });

  app.put('/productos/:id', soloDueno, (req, res, next) => {
    try {
      const producto = actualizarProducto(req.params.id, req.body);
      if (!producto) return res.status(404).json({ error: 'Producto inexistente.' });
      return res.json(producto);
    } catch (error) {
      return next(error);
    }
  });

  app.delete('/productos/:id', soloDueno, (req, res) => {
    res.sendStatus(eliminarProducto(req.params.id) ? 204 : 404);
  });

  // --- IA: foto -> etiqueta (solo el dueño: cada consulta usa la clave de Gemini) ---
  app.post('/ia/etiqueta', soloDueno, async (req, res, next) => {
    try {
      const etiqueta = await armarEtiqueta({
        imagenBase64: req.body?.imagenBase64,
        tipo: req.body?.tipo,
        apiKey: geminiApiKey,
        modelo: geminiModelo,
      });
      res.json(etiqueta);
    } catch (error) {
      next(error);
    }
  });

  // --- Pagos ---
  app.post('/pagos/preferencia', async (req, res, next) => {
    // La política también se hace cumplir acá: aunque una app vieja muestre
    // "Efectivo", el servidor no lo acepta si está apagado.
    if (req.body?.metodoPago === 'efectivo' && !funciones.pagoEnEfectivo) {
      return res.status(400).json({ error: 'Hoy no se acepta efectivo.' });
    }
    try {
      const preferencia = await crearPreferencia({
        cliente: clienteMp,
        pedido: req.body,
        urlPublica,
        urlLocal: urlLocalDe(req),
        sandbox: mpSandbox,
      });
      res.status(201).json(preferencia);
    } catch (error) {
      next(error);
    }
  });

  app.get('/pagos/:pedidoId/estado', async (req, res, next) => {
    try {
      const estado = await consultarEstado({ cliente: clienteMp, pedidoId: req.params.pedidoId });
      if (!estado) return res.status(404).json({ error: 'Pedido inexistente.' });
      return res.json({ estado });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/webhooks/mercadopago', async (req, res) => {
    const idDato = req.body?.data?.id ?? req.query['data.id'];
    const valida = firmaValida({
      secreto: mpWebhookSecret,
      firma: req.get('x-signature'),
      idSolicitud: req.get('x-request-id'),
      idDato,
    });
    if (!valida) return res.sendStatus(401);

    // Se responde rápido; Mercado Pago reintenta si no recibe 200.
    res.sendStatus(200);
    const tipo = req.body?.type ?? req.query.type;
    if (tipo === 'payment') {
      procesarWebhook({ cliente: clienteMp, idPago: idDato }).catch((error) =>
        console.error('Webhook de Mercado Pago:', error.message),
      );
    }
    return undefined;
  });

  // Página a la que vuelve la persona después de pagar.
  app.get('/pago/retorno', (_req, res) => {
    res.type('html').send(pagina('¡Gracias!', 'Ya podés volver a la app de FreshMarket.'));
  });

  // Solo en modo simulado: "pagar" es abrir esta página.
  app.get('/pago/simulado/:pedidoId', (req, res) => {
    if (clienteMp) return res.sendStatus(404);
    if (!buscarPedido(req.params.pedidoId)) return res.sendStatus(404);
    marcarPago(req.params.pedidoId, 'aprobado');
    return res
      .type('html')
      .send(pagina('Pago de prueba aprobado', 'Volvé a la app de FreshMarket.'));
  });

  // --- Seguimiento del reparto ---
  app.get('/pedidos/:pedidoId/seguimiento', (req, res) => {
    const seguimiento = seguimientoDe(req.params.pedidoId, Date.now(), { simularReparto });
    if (!seguimiento) return res.status(404).json({ error: 'Pedido inexistente.' });
    return res.json(seguimiento);
  });

  // Lo que tiene que llevar el repartidor.
  app.get('/repartidores/pedidos', soloReparto, (_req, res) => {
    res.json(
      pedidosParaRepartir().map((pedido) => ({
        id: pedido.id,
        numero: pedido.numero,
        direccion: pedido.direccion,
        destino: pedido.destino,
        total: pedido.total,
        metodoPago: pedido.metodoPago,
        productos: pedido.items.map((item) => `${item.quantity} × ${item.title}`),
      })),
    );
  });

  // Lo usa el modo repartidor de la app para mandar su posición GPS.
  app.post('/repartidores/posicion', soloReparto, (req, res) => {
    const ok = registrarPosicion(req.body ?? {});
    return ok ? res.sendStatus(204) : res.status(400).json({ error: 'Datos inválidos.' });
  });

  // El repartidor avisa que entregó.
  app.post('/pedidos/:pedidoId/entregado', soloReparto, (req, res) => {
    res.sendStatus(marcarEntregado(req.params.pedidoId) ? 204 : 404);
  });

  // --- Notificaciones push: qué celular recibe qué aviso ---
  // El cliente anota su celular para seguir su pedido (no tiene cuenta).
  app.post('/pedidos/:pedidoId/avisos', (req, res) => {
    const token = req.body?.token;
    if (!tokenValido(token)) return res.status(400).json({ error: 'Token inválido.' });
    const pedido = buscarPedido(req.params.pedidoId);
    if (!pedido) return res.status(404).json({ error: 'Pedido inexistente.' });
    anotarParaPedido(token, pedido.id);
    return res.sendStatus(204);
  });

  // El dueño y el repartidor, para enterarse de cada pedido nuevo.
  app.post('/dispositivos', soloReparto, (req, res) => {
    const token = req.body?.token;
    if (!tokenValido(token)) return res.status(400).json({ error: 'Token inválido.' });
    anotarParaRol(token, req.rol);
    return res.sendStatus(204);
  });

  // Sin sesión a propósito: la app lo llama DESPUÉS de cerrarla. Tener el
  // token del celular (largo y secreto) alcanza para darlo de baja.
  app.delete('/dispositivos/:token', (req, res) => {
    olvidarCuenta(req.params.token);
    res.sendStatus(204);
  });

  // eslint-disable-next-line no-unused-vars
  app.use((error, _req, res, _next) => {
    if (error instanceof ErrorDeValidacion) return res.status(400).json({ error: error.message });
    if (error?.type === 'entity.too.large') return res.status(413).json({ error: 'Foto muy pesada.' });
    if (error?.type === 'entity.parse.failed') return res.status(400).json({ error: 'Datos inválidos.' });
    console.error(error);
    return res.status(502).json({ error: 'No pudimos completar la operación.' });
  });

  return app;
}

function pagina(titulo, texto) {
  return `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${titulo}</title>
<style>body{font-family:sans-serif;text-align:center;padding:48px 24px;font-size:22px;color:#1b5e20}</style>
</head><body><h1>${titulo}</h1><p>${texto}</p></body></html>`;
}
