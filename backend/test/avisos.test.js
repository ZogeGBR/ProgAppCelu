// Pruebas de las notificaciones push. node --test corre cada archivo en su
// propio proceso, así que este servidor no se mezcla con el de app.test.js.
//
// Se inyecta un push falso (pushEnConsola) que guarda lo que se habría
// mandado por Firebase: se prueba QUIÉN recibe QUÉ aviso y CUÁNDO.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import { crearApp } from '../src/app.js';
import { obtenerBd } from '../src/bd.js';
import { pushEnConsola } from '../src/push.js';

const DUENO = { email: 'ceferino@freshmarket.test', clave: 'clave-dueno-1' };
const REPARTIDOR = { email: 'tobias@freshmarket.test', clave: 'clave-reparto-1' };
const TOKEN_CLIENTE = 'token-cliente-0001';
const TOKEN_DUENO = 'token-dueno-00001';
const TOKEN_REPARTIDOR = 'token-reparto-0001';

let servidor;
let url;
let push;
let sesionDueno;
let sesionRepartidor;

const pedirA = (base) => (ruta, { body, headers, method } = {}) =>
  fetch(`${base()}${ruta}`, {
    method: method ?? (body ? 'POST' : 'GET'),
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
const pedir = pedirA(() => url);
const conSesion = (token) => ({ authorization: `Bearer ${token}` });

/** Los avisos se mandan sin esperar (no frenan la respuesta): se les da un momento. */
const esperarAvisos = () => new Promise((resolver) => setTimeout(resolver, 30));

const pedidoEfectivo = (id, metodoPago = 'efectivo') => ({
  id,
  metodoPago,
  direccion: 'Belgrano 55',
  items: [{ productoId: 'p2', cantidad: 2 }],
});
const crearPedido = (id, metodoPago) =>
  pedir('/pagos/preferencia', { body: pedidoEfectivo(id, metodoPago) });

/** Levanta un servidor con el push que se le pase. */
async function levantar(opciones) {
  const instancia = crearApp({ geocodificacion: 'simulado', ...opciones }).listen(0);
  await new Promise((resolver) => instancia.once('listening', resolver));
  return { instancia, base: `http://localhost:${instancia.address().port}` };
}

before(async () => {
  push = pushEnConsola();
  const { instancia, base } = await levantar({
    usuariosIniciales: [
      { ...DUENO, nombre: 'Don Ceferino', rol: 'dueno' },
      { ...REPARTIDOR, nombre: 'Tobías', rol: 'repartidor' },
    ],
    push,
  });
  servidor = instancia;
  url = base;

  const ingresar = async (cuenta) =>
    (await (await pedir('/sesiones', { body: cuenta })).json()).token;
  sesionDueno = await ingresar(DUENO);
  sesionRepartidor = await ingresar(REPARTIDOR);
});

after(() => servidor.close());

beforeEach(() => {
  push.enviados.length = 0;
});

describe('anotar celulares', () => {
  test('el cliente se anota para su pedido; un pedido que no existe da 404', async () => {
    await crearPedido('a-1');
    const ok = await pedir('/pedidos/a-1/avisos', { body: { token: TOKEN_CLIENTE } });
    assert.equal(ok.status, 204);

    const noExiste = await pedir('/pedidos/no-existe/avisos', { body: { token: TOKEN_CLIENTE } });
    assert.equal(noExiste.status, 404);
  });

  test('un token vacío, muy corto o que no es texto se rechaza', async () => {
    await crearPedido('a-2');
    for (const token of [undefined, '', 'corto', 123]) {
      const respuesta = await pedir('/pedidos/a-2/avisos', { body: { token } });
      assert.equal(respuesta.status, 400, `token: ${token}`);
    }
  });

  test('anotarse dos veces no duplica el aviso', async () => {
    await crearPedido('a-3');
    await pedir('/pedidos/a-3/avisos', { body: { token: TOKEN_CLIENTE } });
    await pedir('/pedidos/a-3/avisos', { body: { token: TOKEN_CLIENTE } });
    const { cantidad } = obtenerBd()
      .prepare("SELECT COUNT(*) AS cantidad FROM dispositivos WHERE pedido_id = 'a-3'")
      .get();
    assert.equal(cantidad, 1);
  });

  test('anotarse como almacén pide haber ingresado', async () => {
    const sinSesion = await pedir('/dispositivos', { body: { token: TOKEN_DUENO } });
    assert.equal(sinSesion.status, 401);
  });
});

describe('quién recibe qué', () => {
  before(async () => {
    await pedir('/dispositivos', { body: { token: TOKEN_DUENO }, headers: conSesion(sesionDueno) });
    await pedir('/dispositivos', {
      body: { token: TOKEN_REPARTIDOR },
      headers: conSesion(sesionRepartidor),
    });
  });

  test('un pedido en efectivo avisa al dueño y al repartidor, no al cliente', async () => {
    await crearPedido('q-1');
    await esperarAvisos();

    assert.equal(push.enviados.length, 1);
    const [aviso] = push.enviados;
    assert.match(aviso.titulo, /^Nuevo pedido #\d+$/);
    assert.match(aviso.cuerpo, /Belgrano 55/);
    assert.deepEqual([...aviso.tokens].sort(), [TOKEN_DUENO, TOKEN_REPARTIDOR].sort());
    assert.deepEqual(aviso.datos, { tipo: 'nuevoPedido', pedidoId: 'q-1' });
  });

  test('con tarjeta, el aviso al almacén llega recién cuando se aprueba', async () => {
    await crearPedido('q-2', 'debito');
    await esperarAvisos();
    assert.equal(push.enviados.length, 0, 'todavía no se pagó');

    await pedir('/pago/simulado/q-2'); // "Pagar" en modo simulado.
    await esperarAvisos();
    assert.equal(push.enviados.length, 1);
    assert.deepEqual(push.enviados[0].datos, { tipo: 'nuevoPedido', pedidoId: 'q-2' });
  });

  test('el cliente se entera cuando sale el repartidor (una vez) y cuando llega', async () => {
    await crearPedido('q-3');
    await pedir('/pedidos/q-3/avisos', { body: { token: TOKEN_CLIENTE } });
    await esperarAvisos();
    push.enviados.length = 0;

    const posicion = (lat) => ({
      body: { pedidoId: 'q-3', lat, lng: -68.84, nombre: 'Tobías' },
      headers: conSesion(sesionRepartidor),
    });
    await pedir('/repartidores/posicion', posicion(-32.885));
    await pedir('/repartidores/posicion', posicion(-32.884));
    await pedir('/repartidores/posicion', posicion(-32.883));
    await esperarAvisos();

    assert.equal(push.enviados.length, 1, 'cada posición NO manda un aviso nuevo');
    assert.match(push.enviados[0].titulo, /está en camino$/);
    assert.deepEqual(push.enviados[0].tokens, [TOKEN_CLIENTE]);
    assert.deepEqual(push.enviados[0].datos, { tipo: 'pedido', pedidoId: 'q-3' });

    const entregar = { method: 'POST', headers: conSesion(sesionRepartidor) };
    await pedir('/pedidos/q-3/entregado', entregar);
    await pedir('/pedidos/q-3/entregado', entregar); // Dos veces: un solo aviso.
    await esperarAvisos();

    assert.equal(push.enviados.length, 2);
    assert.match(push.enviados[1].titulo, /llegó$/);
    assert.deepEqual(push.enviados[1].tokens, [TOKEN_CLIENTE]);
  });

  test('al cerrar la sesión, ese celular deja de recibir los pedidos nuevos', async () => {
    const borrar = await pedir(`/dispositivos/${TOKEN_REPARTIDOR}`, {
      method: 'DELETE',
      headers: conSesion(sesionRepartidor),
    });
    assert.equal(borrar.status, 204);

    await crearPedido('q-4');
    await esperarAvisos();
    assert.deepEqual(push.enviados[0].tokens, [TOKEN_DUENO]);
  });
});

// Van al final: cada servidor nuevo reabre la base en memoria.
describe('si Firebase falla', () => {
  test('el pedido se crea igual y un token vencido se borra', async () => {
    const intentos = [];
    // Firebase contesta que ese token ya no existe (app desinstalada).
    const { instancia, base } = await levantar({
      push: async (tokens) => {
        intentos.push(tokens);
        return tokens;
      },
    });
    try {
      obtenerBd()
        .prepare(
          "INSERT INTO dispositivos (token, rol, creado_en) VALUES ('token-vencido-1', 'dueno', 0)",
        )
        .run();
      const respuesta = await pedirA(() => base)('/pagos/preferencia', {
        body: pedidoEfectivo('f-1'),
      });
      assert.equal(respuesta.status, 201);
      await esperarAvisos();

      assert.deepEqual(intentos, [['token-vencido-1']]);
      assert.equal(obtenerBd().prepare('SELECT COUNT(*) AS c FROM dispositivos').get().c, 0);
    } finally {
      instancia.close();
    }
  });

  test('un push que tira error no rompe el pedido', async () => {
    const { instancia, base } = await levantar({
      push: async () => {
        throw new Error('Firebase caído');
      },
    });
    try {
      const respuesta = await pedirA(() => base)('/pagos/preferencia', {
        body: pedidoEfectivo('f-2'),
      });
      assert.equal(respuesta.status, 201);
      await esperarAvisos();
    } finally {
      instancia.close();
    }
  });
});
