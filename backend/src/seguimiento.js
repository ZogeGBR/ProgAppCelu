// Seguimiento del reparto en bicicleta.
//
// El celular del repartidor manda su posición con POST /repartidores/posicion.
// Si todavía no hay app de repartidor (demo), se simula el recorrido.
import { pedidos } from './pagos.js';

const ALMACEN = { lat: -32.8895, lng: -68.8458 };
const DESTINO_DEMO = { lat: -32.8805, lng: -68.8335 };

// Duraciones de la simulación (en milisegundos).
export const TIEMPOS = {
  recibido: 15_000,
  preparacion: 20_000,
  viaje: 120_000,
};

/** Última posición conocida de cada pedido: pedidoId -> { lat, lng, nombre, en } */
const posiciones = new Map();

export function registrarPosicion({ pedidoId, lat, lng, nombre }) {
  const latitud = Number(lat);
  const longitud = Number(lng);
  const valida =
    Number.isFinite(latitud) && Math.abs(latitud) <= 90 &&
    Number.isFinite(longitud) && Math.abs(longitud) <= 180;
  if (!pedidos.has(pedidoId) || !valida) return false;

  posiciones.set(pedidoId, {
    lat: latitud,
    lng: longitud,
    nombre: String(nombre ?? 'Repartidor').slice(0, 40),
    en: Date.now(),
  });
  return true;
}

export function marcarEntregado(pedidoId) {
  const registro = pedidos.get(pedidoId);
  if (!registro || registro.estadoPago !== 'aprobado') return false;
  registro.entregado = true;
  return true;
}

export function seguimientoDe(pedidoId, ahora = Date.now()) {
  const registro = pedidos.get(pedidoId);
  if (!registro) return null;
  if (registro.estadoPago !== 'aprobado') return { estado: 'recibido' };

  const real = posiciones.get(pedidoId);
  if (real) {
    return {
      estado: registro.entregado ? 'entregado' : 'enCamino',
      repartidor: { nombre: real.nombre, lat: real.lat, lng: real.lng },
      destino: DESTINO_DEMO,
    };
  }
  return simular(ahora - registro.aprobadoEn);
}

function simular(transcurrido) {
  const { recibido, preparacion, viaje } = TIEMPOS;
  if (transcurrido < recibido) return { estado: 'recibido' };
  if (transcurrido < recibido + preparacion) return { estado: 'enPreparacion' };

  const avance = (transcurrido - recibido - preparacion) / viaje;
  if (avance >= 1) return { estado: 'entregado', destino: DESTINO_DEMO };

  return {
    estado: 'enCamino',
    repartidor: {
      nombre: 'Tobías',
      lat: ALMACEN.lat + (DESTINO_DEMO.lat - ALMACEN.lat) * avance,
      lng: ALMACEN.lng + (DESTINO_DEMO.lng - ALMACEN.lng) * avance,
    },
    destino: DESTINO_DEMO,
    minutosEstimados: Math.ceil(((1 - avance) * viaje) / 60_000),
  };
}
