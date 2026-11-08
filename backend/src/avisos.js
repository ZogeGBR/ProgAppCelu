// Qué celular recibe qué aviso, y el envío cuando pasa algo con un pedido.
//
// - El cliente no tiene cuenta: su celular se anota para UN pedido
//   (POST /pedidos/:id/avisos) y se entera cuando sale y cuando llega.
// - El dueño y el repartidor anotan su celular al ingresar
//   (POST /dispositivos) y se enteran de cada pedido nuevo.
import { obtenerBd } from './bd.js';
import { EVENTOS } from './eventos.js';

const LARGO_MAXIMO_TOKEN = 4096;

export function tokenValido(token) {
  return typeof token === 'string' && token.length >= 10 && token.length <= LARGO_MAXIMO_TOKEN;
}

export function anotarParaPedido(token, pedidoId) {
  obtenerBd()
    .prepare(
      `INSERT OR IGNORE INTO dispositivos (token, pedido_id, rol, creado_en)
       VALUES (?, ?, NULL, ?)`,
    )
    .run(token, pedidoId, Date.now());
}

export function anotarParaRol(token, rol) {
  obtenerBd()
    .prepare(
      `INSERT OR IGNORE INTO dispositivos (token, pedido_id, rol, creado_en)
       VALUES (?, NULL, ?, ?)`,
    )
    .run(token, rol, Date.now());
}

/** Al cerrar la sesión: ese celular deja de recibir los avisos del almacén. */
export function olvidarCuenta(token) {
  obtenerBd().prepare('DELETE FROM dispositivos WHERE token = ? AND rol IS NOT NULL').run(token);
}

function tokensDePedido(pedidoId) {
  return obtenerBd()
    .prepare('SELECT token FROM dispositivos WHERE pedido_id = ?')
    .all(pedidoId)
    .map((fila) => fila.token);
}

function tokensDelAlmacen() {
  return obtenerBd()
    .prepare('SELECT DISTINCT token FROM dispositivos WHERE rol IS NOT NULL')
    .all()
    .map((fila) => fila.token);
}

function borrarTokens(tokens) {
  const borrar = obtenerBd().prepare('DELETE FROM dispositivos WHERE token = ?');
  for (const token of tokens) borrar.run(token);
}

/** Suscribe los avisos a los eventos del negocio (patrón Observer). */
export function conectarAvisos(eventos, enviar) {
  const mandar = async (tokens, aviso) => {
    try {
      borrarTokens(await enviar(tokens, aviso));
    } catch (error) {
      // Un push que falla nunca frena un pago ni una entrega.
      console.error('No se pudo mandar el aviso:', error.message);
    }
  };

  eventos.on(EVENTOS.pedidoAprobado, (pedido) =>
    mandar(tokensDelAlmacen(), {
      titulo: `Nuevo pedido #${pedido.numero}`,
      cuerpo: `$${pedido.total.toLocaleString('es-AR')} · ${pedido.direccion}`,
      datos: { tipo: 'nuevoPedido', pedidoId: pedido.id },
    }),
  );

  eventos.on(EVENTOS.repartoEmpezado, (pedido) =>
    mandar(tokensDePedido(pedido.id), {
      titulo: `Tu pedido #${pedido.numero} está en camino`,
      cuerpo: 'El repartidor ya salió en bici. Seguilo en el mapa.',
      datos: { tipo: 'pedido', pedidoId: pedido.id },
    }),
  );

  eventos.on(EVENTOS.pedidoEntregado, (pedido) =>
    mandar(tokensDePedido(pedido.id), {
      titulo: `Tu pedido #${pedido.numero} llegó`,
      cuerpo: '¡Que lo disfrutes! Gracias por comprar en el almacén.',
      datos: { tipo: 'pedido', pedidoId: pedido.id },
    }),
  );
}
