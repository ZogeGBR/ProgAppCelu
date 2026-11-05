// Rutas HTTP del backend de FreshMarket.
import express from 'express';

import { agregarProducto, ErrorDeValidacion, listarProductos } from './catalogo.js';
import { armarEtiqueta } from './ia.js';
import {
  consultarEstado,
  crearClienteMercadoPago,
  crearPreferencia,
  firmaValida,
  marcarPago,
  pedidos,
  procesarWebhook,
} from './pagos.js';
import { marcarEntregado, registrarPosicion, seguimientoDe } from './seguimiento.js';

export function crearApp(config = {}) {
  const {
    mpAccessToken,
    mpSandbox = false,
    mpWebhookSecret,
    geminiApiKey,
    geminiModelo = 'gemini-2.5-flash',
    urlPublica,
    claveRepartidor,
  } = config;

  const clienteMp = crearClienteMercadoPago(mpAccessToken);
  const app = express();
  app.use(express.json({ limit: '8mb' }));

  const urlLocalDe = (req) => urlPublica || `${req.protocol}://${req.get('host')}`;

  app.get('/salud', (_req, res) => {
    res.json({
      ok: true,
      mercadoPago: clienteMp ? 'real' : 'simulado',
      ia: geminiApiKey ? 'gemini' : 'simulada',
    });
  });

  // --- Catálogo ---
  app.get('/productos', (_req, res) => res.json(listarProductos()));

  app.post('/productos', (req, res, next) => {
    try {
      res.status(201).json(agregarProducto(req.body));
    } catch (error) {
      next(error);
    }
  });

  // --- IA: foto -> etiqueta ---
  app.post('/ia/etiqueta', async (req, res, next) => {
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
    if (!pedidos.has(req.params.pedidoId)) return res.sendStatus(404);
    marcarPago(req.params.pedidoId, 'aprobado');
    return res
      .type('html')
      .send(pagina('Pago de prueba aprobado', 'Volvé a la app de FreshMarket.'));
  });

  // --- Seguimiento del reparto ---
  app.get('/pedidos/:pedidoId/seguimiento', (req, res) => {
    const seguimiento = seguimientoDe(req.params.pedidoId);
    if (!seguimiento) return res.status(404).json({ error: 'Pedido inexistente.' });
    return res.json(seguimiento);
  });

  // Lo usa la app del repartidor para mandar su posición GPS.
  app.post('/repartidores/posicion', (req, res) => {
    if (claveRepartidor && req.get('x-clave-repartidor') !== claveRepartidor) {
      return res.sendStatus(401);
    }
    const ok = registrarPosicion(req.body ?? {});
    return ok ? res.sendStatus(204) : res.status(400).json({ error: 'Datos inválidos.' });
  });

  // El repartidor avisa que entregó.
  app.post('/pedidos/:pedidoId/entregado', (req, res) => {
    if (claveRepartidor && req.get('x-clave-repartidor') !== claveRepartidor) {
      return res.sendStatus(401);
    }
    return marcarEntregado(req.params.pedidoId) ? res.sendStatus(204) : res.sendStatus(404);
  });

  // eslint-disable-next-line no-unused-vars
  app.use((error, _req, res, _next) => {
    if (error instanceof ErrorDeValidacion) return res.status(400).json({ error: error.message });
    if (error?.type === 'entity.too.large') return res.status(413).json({ error: 'Foto muy pesada.' });
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
