// Cuántos pedidos toma el almacén.
//
// Don Ceferino pidió 5.000 pedidos simultáneos sin pagar servidores, y esas
// dos cosas son incompatibles. Un almacén de barrio recibe hasta unos 100
// pedidos por día, y el límite real son los repartidores en bicicleta (con
// dos, salen unas 40 a 60 entregas por día). Por eso el sistema se
// dimensiona para 100: alcanza un servidor chico y barato, que es lo que
// pidió el cliente.
//
// - Por día: como máximo MAX_POR_DIA pedidos aprobados (los que hay que
//   entregar). Un pago abandonado no ocupa lugar.
// - Por minuto: como máximo MAX_POR_MINUTO pedidos nuevos. Protege al
//   servidor chico de un pico (Nochebuena) sin rechazar a nadie por mucho
//   tiempo: al minuto siguiente vuelve a haber lugar.
//
// Los dos se cambian con MAX_PEDIDOS_POR_DIA y MAX_PEDIDOS_POR_MINUTO.
import { obtenerBd } from './bd.js';

export const MAX_POR_DIA = 100;
export const MAX_POR_MINUTO = 100;

const UN_MINUTO = 60 * 1000;
const UN_DIA = 24 * 60 * 60 * 1000;
// Argentina está en UTC-3 todo el año (no tiene horario de verano).
const DESFASE_ARGENTINA = -3 * 60 * 60 * 1000;

export const LIMITES = Object.freeze({ porDia: 'porDia', porMinuto: 'porMinuto' });

/** Las 00:00 de hoy en Argentina, en milisegundos desde 1970. */
export function inicioDelDia(ahora) {
  const local = ahora + DESFASE_ARGENTINA;
  return local - (local % UN_DIA) - DESFASE_ARGENTINA;
}

/** Pedidos aprobados desde un momento (para el tope del día). */
export function aprobadosDesde(desde) {
  return obtenerBd()
    .prepare(
      `SELECT COUNT(*) AS cantidad FROM pedidos
       WHERE estado_pago = 'aprobado' AND aprobado_en >= ?`,
    )
    .get(desde).cantidad;
}

/**
 * Devuelve una función que pide lugar para un pedido nuevo: null si hay
 * lugar (y lo ocupa), o el límite alcanzado ('porDia' o 'porMinuto').
 * `ahora` se puede reemplazar en las pruebas para no esperar un minuto.
 */
export function crearCupo({
  porDia = MAX_POR_DIA,
  porMinuto = MAX_POR_MINUTO,
  ahora = Date.now,
} = {}) {
  // Momentos de los pedidos del último minuto (ventana deslizante).
  const recientes = [];

  return function pedirLugar() {
    const momento = ahora();
    while (recientes.length > 0 && recientes[0] <= momento - UN_MINUTO) {
      recientes.shift();
    }
    if (aprobadosDesde(inicioDelDia(momento)) >= porDia) return LIMITES.porDia;
    if (recientes.length >= porMinuto) return LIMITES.porMinuto;
    recientes.push(momento);
    return null;
  };
}
