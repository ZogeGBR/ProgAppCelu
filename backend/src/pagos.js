// Pagos con Mercado Pago (Checkout Pro).
//
// El Access Token vive SOLO acá (variable de entorno MP_ACCESS_TOKEN).
// Sin token, el backend funciona en modo simulado para la demo.
import crypto from 'node:crypto';
import { MercadoPagoConfig, Payment, Preference } from 'mercadopago';

import { obtenerBd } from './bd.js';
import { anunciar, EVENTOS } from './eventos.js';
import { buscarProducto, ErrorDeValidacion } from './catalogo.js';

const MAXIMA_CANTIDAD = 99;
const LARGO_ID = 64;
const LARGO_DIRECCION = 200;

/** Se paga al repartidor: el pedido no pasa por Mercado Pago. */
const EFECTIVO = 'efectivo';

/** Convierte una fila de la base en el registro que usa el resto del backend. */
function aRegistro(fila) {
  return {
    id: fila.id,
    numero: fila.numero,
    metodoPago: fila.metodo_pago,
    items: JSON.parse(fila.items),
    total: fila.total,
    direccion: fila.direccion,
    destino:
      fila.destino_lat === null ? null : { lat: fila.destino_lat, lng: fila.destino_lng },
    estadoPago: fila.estado_pago,
    aprobadoEn: fila.aprobado_en,
    entregado: fila.entregado === 1,
  };
}

export function buscarPedido(id) {
  const fila = obtenerBd().prepare('SELECT * FROM pedidos WHERE id = ?').get(String(id));
  return fila ? aRegistro(fila) : null;
}

/** Pedidos confirmados que el repartidor todavía tiene que llevar. */
export function pedidosParaRepartir() {
  return obtenerBd()
    .prepare(
      `SELECT * FROM pedidos WHERE estado_pago = 'aprobado' AND entregado = 0
       ORDER BY aprobado_en`,
    )
    .all()
    .map(aRegistro);
}

// Qué medios NO se muestran según lo que eligió la persona en la app.
// Así ve directamente lo que eligió y no se confunde con otras opciones.
const EXCLUSIONES = {
  debito: ['credit_card', 'ticket', 'atm', 'prepaid_card'],
  credito: ['debit_card', 'ticket', 'atm', 'prepaid_card'],
  billeteraMercadoPago: ['credit_card', 'debit_card', 'ticket', 'atm', 'prepaid_card'],
};

export function crearClienteMercadoPago(accessToken) {
  if (!accessToken) return null;
  return new MercadoPagoConfig({ accessToken, options: { timeout: 10000 } });
}

/**
 * Recalcula el pedido con los precios DEL SERVIDOR. El total que mande la
 * app no se usa nunca: alguien podría modificarlo.
 */
export function armarItems(pedido) {
  if (!pedido?.id || !Array.isArray(pedido.items) || pedido.items.length === 0) {
    throw new ErrorDeValidacion('El pedido no tiene productos.');
  }
  if (pedido.metodoPago !== EFECTIVO && !(pedido.metodoPago in EXCLUSIONES)) {
    throw new ErrorDeValidacion('Medio de pago desconocido.');
  }

  return pedido.items.map((item) => {
    const producto = buscarProducto(item.productoId);
    const cantidad = Number(item.cantidad);
    if (!producto) throw new ErrorDeValidacion(`No existe el producto ${item.productoId}.`);
    if (!producto.disponible) throw new ErrorDeValidacion(`No hay más ${producto.nombre}.`);
    if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > MAXIMA_CANTIDAD) {
      throw new ErrorDeValidacion('Cantidad inválida.');
    }
    return {
      id: producto.id,
      title: producto.nombre,
      quantity: cantidad,
      unit_price: producto.precio,
      currency_id: 'ARS',
    };
  });
}

function validarDireccion(valor) {
  const direccion = String(valor ?? '').trim();
  if (!direccion) throw new ErrorDeValidacion('Falta la dirección de entrega.');
  return direccion.slice(0, LARGO_DIRECCION);
}

function validarDestino(destino) {
  if (destino === undefined || destino === null) return null;
  const lat = Number(destino.lat);
  const lng = Number(destino.lng);
  if (!Number.isFinite(lat) || Math.abs(lat) > 90 || !Number.isFinite(lng) || Math.abs(lng) > 180) {
    throw new ErrorDeValidacion('La ubicación de entrega no es válida.');
  }
  return { lat, lng };
}

/**
 * Guarda el pedido. El número lo asigna la base: si lo eligiera cada celular,
 * dos clientes tendrían el mismo. Un id repetido se rechaza para que nadie
 * pueda pisar un pedido ya pagado.
 */
function guardarPedido(pedido, items, total) {
  const id = String(pedido.id).slice(0, LARGO_ID);
  const direccion = validarDireccion(pedido.direccion);
  const destino = validarDestino(pedido.destino);
  if (buscarPedido(id)) throw new ErrorDeValidacion('Ese pedido ya existe.');

  // En efectivo no hay nada que esperar: el pedido sale directo.
  const efectivo = pedido.metodoPago === EFECTIVO;
  const { lastInsertRowid } = obtenerBd()
    .prepare(
      `INSERT INTO pedidos
         (id, metodo_pago, items, total, direccion, destino_lat, destino_lng,
          estado_pago, aprobado_en)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .run(
      id,
      pedido.metodoPago,
      JSON.stringify(items),
      total,
      direccion,
      destino?.lat ?? null,
      destino?.lng ?? null,
      efectivo ? 'aprobado' : 'pendiente',
      efectivo ? Date.now() : null,
    );
  if (efectivo) anunciar(EVENTOS.pedidoAprobado, buscarPedido(id));
  return { id, numero: Number(lastInsertRowid) };
}

export async function crearPreferencia({ cliente, pedido, urlPublica, urlLocal, sandbox }) {
  const items = armarItems(pedido);
  const total = items.reduce((suma, item) => suma + item.unit_price * item.quantity, 0);
  const { id, numero } = guardarPedido(pedido, items, total);

  if (pedido.metodoPago === EFECTIVO) {
    return { preferenciaId: null, urlCheckout: null, total, numero };
  }

  if (!cliente) {
    return {
      preferenciaId: `simulada-${id}`,
      urlCheckout: `${urlLocal}/pago/simulado/${encodeURIComponent(id)}`,
      total,
      numero,
    };
  }

  const cuerpo = {
    items,
    external_reference: id,
    statement_descriptor: 'FRESHMARKET',
    payment_methods: {
      excluded_payment_types: EXCLUSIONES[pedido.metodoPago].map((id) => ({ id })),
      installments: pedido.metodoPago === 'credito' ? 6 : 1,
    },
  };
  // Mercado Pago solo acepta URLs públicas (https) para volver y avisar.
  if (urlPublica?.startsWith('https://')) {
    const retorno = `${urlPublica}/pago/retorno`;
    cuerpo.back_urls = { success: retorno, failure: retorno, pending: retorno };
    cuerpo.auto_return = 'approved';
    cuerpo.notification_url = `${urlPublica}/webhooks/mercadopago`;
  }

  const preferencia = await new Preference(cliente).create({ body: cuerpo });
  return {
    preferenciaId: preferencia.id,
    urlCheckout: sandbox ? preferencia.sandbox_init_point : preferencia.init_point,
    total,
    numero,
  };
}

/** Traduce el estado de Mercado Pago al que entiende la app. */
export function traducirEstado(estadoMercadoPago) {
  if (estadoMercadoPago === 'approved') return 'aprobado';
  if (['rejected', 'cancelled', 'refunded', 'charged_back'].includes(estadoMercadoPago)) {
    return 'rechazado';
  }
  return 'pendiente';
}

export function marcarPago(pedidoId, estado) {
  const registro = buscarPedido(pedidoId);
  if (!registro || registro.estadoPago === 'aprobado') return;
  obtenerBd()
    .prepare('UPDATE pedidos SET estado_pago = ?, aprobado_en = ? WHERE id = ?')
    .run(estado, estado === 'aprobado' ? Date.now() : null, pedidoId);
  if (estado === 'aprobado') anunciar(EVENTOS.pedidoAprobado, buscarPedido(pedidoId));
}

/**
 * Estado del pago de un pedido. Si el webhook todavía no avisó, se le
 * pregunta a Mercado Pago buscando por la referencia externa.
 */
export async function consultarEstado({ cliente, pedidoId }) {
  const registro = buscarPedido(pedidoId);
  if (!registro) return null;
  if (registro.estadoPago !== 'pendiente' || !cliente) return registro.estadoPago;

  const resultado = await new Payment(cliente).search({
    options: { external_reference: pedidoId, sort: 'date_created', criteria: 'desc' },
  });
  const ultimo = resultado.results?.[0];
  if (ultimo) marcarPago(pedidoId, traducirEstado(ultimo.status));
  return buscarPedido(pedidoId).estadoPago;
}

/** Procesa el aviso (webhook) de Mercado Pago de un pago nuevo o actualizado. */
export async function procesarWebhook({ cliente, idPago }) {
  if (!cliente || !idPago) return;
  const pago = await new Payment(cliente).get({ id: idPago });
  if (pago.external_reference) {
    marcarPago(pago.external_reference, traducirEstado(pago.status));
  }
}

/**
 * Verifica la firma x-signature del webhook (si hay MP_WEBHOOK_SECRET).
 * Formato: "ts=...,v1=..."; se firma "id:<data.id>;request-id:<x-request-id>;ts:<ts>;".
 */
export function firmaValida({ secreto, firma, idSolicitud, idDato }) {
  if (!secreto) return true;
  if (!firma) return false;
  const partes = Object.fromEntries(
    firma.split(',').map((parte) => parte.trim().split('=')),
  );
  if (!partes.ts || !partes.v1) return false;

  const id = String(idDato ?? '').toLowerCase();
  const manifiesto = `id:${id};request-id:${idSolicitud ?? ''};ts:${partes.ts};`;
  const esperado = crypto.createHmac('sha256', secreto).update(manifiesto).digest('hex');
  const a = Buffer.from(esperado);
  const b = Buffer.from(partes.v1);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
