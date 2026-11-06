// Seguimiento del reparto en bicicleta.
//
// El celular del repartidor manda su posición con POST /repartidores/posicion.
// En la demo, mientras no mande nada, se simula el recorrido. Con pagos reales
// la simulación se apaga: un cliente nunca tiene que ver un repartidor inventado.
import { obtenerBd } from './bd.js';
import { buscarPedido } from './pagos.js';

const ALMACEN = { lat: -32.8895, lng: -68.8458 };
const DESTINO_DEMO = { lat: -32.8805, lng: -68.8335 };

const RADIO_TIERRA_KM = 6371;
const VELOCIDAD_BICI_KM_H = 15;

// Duraciones de la simulación (en milisegundos).
export const TIEMPOS = {
  recibido: 15_000,
  preparacion: 20_000,
  viaje: 120_000,
};

export function registrarPosicion({ pedidoId, lat, lng, nombre }) {
  const latitud = Number(lat);
  const longitud = Number(lng);
  const valida =
    Number.isFinite(latitud) && Math.abs(latitud) <= 90 &&
    Number.isFinite(longitud) && Math.abs(longitud) <= 180;
  if (!valida || !buscarPedido(pedidoId)) return false;

  obtenerBd()
    .prepare(
      `INSERT INTO posiciones (pedido_id, lat, lng, nombre, en) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT (pedido_id) DO UPDATE SET
         lat = excluded.lat, lng = excluded.lng, nombre = excluded.nombre, en = excluded.en`,
    )
    .run(pedidoId, latitud, longitud, String(nombre ?? 'Repartidor').slice(0, 40), Date.now());
  return true;
}

export function marcarEntregado(pedidoId) {
  const registro = buscarPedido(pedidoId);
  if (!registro || registro.estadoPago !== 'aprobado') return false;
  obtenerBd().prepare('UPDATE pedidos SET entregado = 1 WHERE id = ?').run(pedidoId);
  return true;
}

/** Distancia en km entre dos puntos (fórmula de Haversine). */
export function distanciaKm(a, b) {
  const rad = (grados) => (grados * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * RADIO_TIERRA_KM * Math.asin(Math.sqrt(h));
}

function minutosHasta(desde, hasta) {
  return Math.max(1, Math.ceil((distanciaKm(desde, hasta) / VELOCIDAD_BICI_KM_H) * 60));
}

export function seguimientoDe(pedidoId, ahora = Date.now(), { simularReparto = true } = {}) {
  const registro = buscarPedido(pedidoId);
  if (!registro) return null;
  if (registro.estadoPago !== 'aprobado') return { estado: 'recibido' };

  const destino = registro.destino ?? DESTINO_DEMO;
  if (registro.entregado) return { estado: 'entregado', destino };

  const real = obtenerBd().prepare('SELECT * FROM posiciones WHERE pedido_id = ?').get(pedidoId);
  if (real) {
    return {
      estado: 'enCamino',
      repartidor: { nombre: real.nombre, lat: real.lat, lng: real.lng },
      destino,
      minutosEstimados: minutosHasta(real, destino),
    };
  }
  if (!simularReparto) return { estado: 'enPreparacion', destino };
  return simular(ahora - registro.aprobadoEn, destino);
}

function simular(transcurrido, destino) {
  const { recibido, preparacion, viaje } = TIEMPOS;
  if (transcurrido < recibido) return { estado: 'recibido' };
  if (transcurrido < recibido + preparacion) return { estado: 'enPreparacion' };

  const avance = (transcurrido - recibido - preparacion) / viaje;
  if (avance >= 1) return { estado: 'entregado', destino };

  return {
    estado: 'enCamino',
    repartidor: {
      nombre: 'Tobías',
      lat: ALMACEN.lat + (destino.lat - ALMACEN.lat) * avance,
      lng: ALMACEN.lng + (destino.lng - ALMACEN.lng) * avance,
    },
    destino,
    minutosEstimados: Math.ceil(((1 - avance) * viaje) / 60_000),
  };
}
