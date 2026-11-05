// Pagos con Mercado Pago (Checkout Pro).
//
// El Access Token vive SOLO acá (variable de entorno MP_ACCESS_TOKEN).
// Sin token, el backend funciona en modo simulado para la demo.
import crypto from 'node:crypto';
import { MercadoPagoConfig, Payment, Preference } from 'mercadopago';

import { buscarProducto, ErrorDeValidacion } from './catalogo.js';

const MAXIMA_CANTIDAD = 99;

/** Pedidos en memoria: id -> { pedido, items, total, estadoPago, aprobadoEn } */
export const pedidos = new Map();

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
  if (!(pedido.metodoPago in EXCLUSIONES)) {
    throw new ErrorDeValidacion('Medio de pago desconocido.');
  }

  return pedido.items.map((item) => {
    const producto = buscarProducto(item.productoId);
    const cantidad = Number(item.cantidad);
    if (!producto) throw new ErrorDeValidacion(`No existe el producto ${item.productoId}.`);
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

export async function crearPreferencia({ cliente, pedido, urlPublica, urlLocal, sandbox }) {
  const items = armarItems(pedido);
  const total = items.reduce((suma, item) => suma + item.unit_price * item.quantity, 0);
  pedidos.set(pedido.id, { pedido, items, total, estadoPago: 'pendiente', aprobadoEn: null });

  if (!cliente) {
    return {
      preferenciaId: `simulada-${pedido.id}`,
      urlCheckout: `${urlLocal}/pago/simulado/${encodeURIComponent(pedido.id)}`,
      total,
    };
  }

  const cuerpo = {
    items,
    external_reference: pedido.id,
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
  const registro = pedidos.get(pedidoId);
  if (!registro || registro.estadoPago === 'aprobado') return;
  registro.estadoPago = estado;
  if (estado === 'aprobado') registro.aprobadoEn = Date.now();
}

/**
 * Estado del pago de un pedido. Si el webhook todavía no avisó, se le
 * pregunta a Mercado Pago buscando por la referencia externa.
 */
export async function consultarEstado({ cliente, pedidoId }) {
  const registro = pedidos.get(pedidoId);
  if (!registro) return null;
  if (registro.estadoPago !== 'pendiente' || !cliente) return registro.estadoPago;

  const resultado = await new Payment(cliente).search({
    options: { external_reference: pedidoId, sort: 'date_created', criteria: 'desc' },
  });
  const ultimo = resultado.results?.[0];
  if (ultimo) marcarPago(pedidoId, traducirEstado(ultimo.status));
  return registro.estadoPago;
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
