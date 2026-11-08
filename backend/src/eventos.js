// Eventos del negocio: el patrón Observer también en el backend.
//
// Pagos y seguimiento solo ANUNCIAN lo que pasó ("se aprobó el pedido",
// "el repartidor salió", "se entregó"). No saben quién escucha. El módulo de
// avisos (avisos.js) se suscribe y manda las notificaciones push. Si mañana
// hay que mandar también un mail, se agrega otro oyente sin tocar los pagos.
//
// Como la base (bd.js), hay UNA sola instancia por servidor: crearApp() la
// renueva con reiniciarEventos() para que dos servidores de prueba no se
// mezclen.
import { EventEmitter } from 'node:events';

export const EVENTOS = {
  pedidoAprobado: 'pedidoAprobado',
  repartoEmpezado: 'repartoEmpezado',
  pedidoEntregado: 'pedidoEntregado',
};

let emisor = new EventEmitter();

export function reiniciarEventos() {
  emisor.removeAllListeners();
  emisor = new EventEmitter();
  return emisor;
}

export function anunciar(evento, pedido) {
  emisor.emit(evento, pedido);
}
