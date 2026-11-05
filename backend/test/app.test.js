// Pruebas del backend en modo simulado (sin claves externas): node --test
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

import { crearApp } from '../src/app.js';
import { abrirBd } from '../src/bd.js';
import { agregarProducto, buscarProducto } from '../src/catalogo.js';
import { normalizar } from '../src/ia.js';
import { firmaValida, traducirEstado } from '../src/pagos.js';
import { seguimientoDe, TIEMPOS } from '../src/seguimiento.js';
import { crearToken, rolDeClave, rolDeToken } from '../src/sesiones.js';

let servidor;
let url;
let tokenDueno;
let tokenRepartidor;

const pedir = (ruta, opciones = {}) =>
  fetch(`${url}${ruta}`, {
    ...opciones,
    headers: { 'Content-Type': 'application/json', ...opciones.headers },
    body: opciones.body ? JSON.stringify(opciones.body) : undefined,
  });

const conToken = (token) => ({ authorization: `Bearer ${token}` });

before(async () => {
  servidor = crearApp({ claveDueno: 'clave-dueno', claveRepartidor: 'clave-reparto' }).listen(0);
  await new Promise((resolver) => servidor.once('listening', resolver));
  url = `http://localhost:${servidor.address().port}`;

  const ingresar = async (clave) =>
    (await (await pedir('/sesiones', { method: 'POST', body: { clave } })).json()).token;
  tokenDueno = await ingresar('clave-dueno');
  tokenRepartidor = await ingresar('clave-reparto');
});

after(() => servidor.close());

const pedidoDePrueba = (id, items = [{ productoId: 'p2', cantidad: 2 }]) => ({
  id,
  metodoPago: 'debito',
  direccion: 'San Martín 1234',
  items,
});

describe('sesiones', () => {
  test('cada clave entra con su rol y una clave mala no entra', async () => {
    const dueno = await pedir('/sesiones', { method: 'POST', body: { clave: 'clave-dueno' } });
    assert.equal((await dueno.json()).rol, 'dueno');

    const mala = await pedir('/sesiones', { method: 'POST', body: { clave: 'cualquiera' } });
    assert.equal(mala.status, 401);
  });

  test('sin clave configurada nadie entra', () => {
    assert.equal(rolDeClave('cualquiera', {}), null);
    assert.equal(rolDeClave('', { claveDueno: '' }), null);
    assert.equal(rolDeClave(undefined, { claveDueno: 'x' }), null);
  });

  test('un token vencido o modificado no sirve', () => {
    const token = crearToken('dueno', 'secreto');
    assert.equal(rolDeToken(token, 'secreto'), 'dueno');
    assert.equal(rolDeToken(token, 'otro-secreto'), null);
    assert.equal(rolDeToken(`${token}x`, 'secreto'), null);

    const hace2Dias = Date.now() - 2 * 24 * 60 * 60 * 1000;
    assert.equal(rolDeToken(crearToken('dueno', 'secreto', hace2Dias), 'secreto'), null);
  });

  test('frena a quien prueba muchas claves', async () => {
    const respuestas = [];
    for (let i = 0; i < 12; i += 1) {
      respuestas.push((await pedir('/sesiones', { method: 'POST', body: { clave: `x${i}` } })).status);
    }
    assert.ok(respuestas.includes(429));
  });
});

describe('catálogo', () => {
  test('devuelve los productos', async () => {
    const productos = await (await pedir('/productos')).json();
    assert.ok(productos.length >= 8);
    assert.equal(productos[0].disponible, true);
  });

  test('solo el dueño puede cambiar el catálogo', async () => {
    const nuevo = { nombre: 'Algo', precio: 100 };
    const sinSesion = await pedir('/productos', { method: 'POST', body: nuevo });
    const repartidor = await pedir('/productos', {
      method: 'POST',
      body: nuevo,
      headers: conToken(tokenRepartidor),
    });
    const editar = await pedir('/productos/p1', { method: 'PUT', body: { precio: 1 } });
    const borrar = await pedir('/productos/p1', { method: 'DELETE' });

    assert.equal(sinSesion.status, 401);
    assert.equal(repartidor.status, 403);
    assert.equal(editar.status, 401);
    assert.equal(borrar.status, 401);
    assert.equal(buscarProducto('p1').precio, 1200);
  });

  test('valida el producto nuevo', async () => {
    const headers = conToken(tokenDueno);
    const sinPrecio = await pedir('/productos', {
      method: 'POST',
      headers,
      body: { nombre: 'Algo', precio: 0 },
    });
    assert.equal(sinPrecio.status, 400);

    const creado = await pedir('/productos', {
      method: 'POST',
      headers,
      body: { nombre: 'Aceite 1.5L', precio: 3200, categoria: 'Inventada' },
    });
    assert.equal(creado.status, 201);
    assert.equal((await creado.json()).categoria, 'Otros');
  });

  test('el dueño cambia el precio, marca sin stock y borra', async () => {
    const headers = conToken(tokenDueno);
    const { id } = agregarProducto({ nombre: 'Para editar', precio: 100 });

    const precio = await pedir(`/productos/${id}`, { method: 'PUT', headers, body: { precio: 250 } });
    assert.equal((await precio.json()).precio, 250);

    const malo = await pedir(`/productos/${id}`, { method: 'PUT', headers, body: { precio: -1 } });
    assert.equal(malo.status, 400);

    const sinStock = await pedir(`/productos/${id}`, {
      method: 'PUT',
      headers,
      body: { disponible: false },
    });
    assert.equal((await sinStock.json()).disponible, false);

    const comprar = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: pedidoDePrueba('sin-stock', [{ productoId: id, cantidad: 1 }]),
    });
    assert.equal(comprar.status, 400);

    assert.equal((await pedir(`/productos/${id}`, { method: 'DELETE', headers })).status, 204);
    assert.equal((await pedir(`/productos/${id}`, { method: 'DELETE', headers })).status, 404);
  });
});

describe('pagos', () => {
  test('el total lo calcula el servidor, no la app', async () => {
    const pedido = {
      ...pedidoDePrueba('t-1'),
      items: [{ productoId: 'p2', cantidad: 2, precioUnitario: 1 }],
      total: 2,
    };
    const respuesta = await pedir('/pagos/preferencia', { method: 'POST', body: pedido });
    const preferencia = await respuesta.json();

    assert.equal(respuesta.status, 201);
    assert.equal(preferencia.total, 3800 * 2);
    assert.match(preferencia.urlCheckout, /\/pago\/simulado\/t-1$/);
  });

  test('el número de pedido lo asigna el servidor y no se repite', async () => {
    const crear = async (id) =>
      (await (await pedir('/pagos/preferencia', { method: 'POST', body: pedidoDePrueba(id) })).json())
        .numero;
    const primero = await crear('num-1');
    const segundo = await crear('num-2');

    assert.ok(primero >= 1001);
    assert.equal(segundo, primero + 1);
  });

  test('no se puede pisar un pedido que ya existe', async () => {
    const pedido = pedidoDePrueba('t-pisar');
    await pedir('/pagos/preferencia', { method: 'POST', body: pedido });
    await pedir('/pago/simulado/t-pisar');

    const otraVez = await pedir('/pagos/preferencia', { method: 'POST', body: pedido });

    assert.equal(otraVez.status, 400);
    assert.equal((await (await pedir('/pagos/t-pisar/estado')).json()).estado, 'aprobado');
  });

  test('rechaza productos inexistentes, cantidades raras y sin dirección', async () => {
    const inexistente = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: pedidoDePrueba('t-2', [{ productoId: 'nada', cantidad: 1 }]),
    });
    const negativa = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: pedidoDePrueba('t-3', [{ productoId: 'p1', cantidad: -4 }]),
    });
    const sinDireccion = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: { ...pedidoDePrueba('t-3b'), direccion: '   ' },
    });
    const destinoMalo = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: { ...pedidoDePrueba('t-3c'), destino: { lat: 500, lng: 0 } },
    });
    assert.equal(inexistente.status, 400);
    assert.equal(negativa.status, 400);
    assert.equal(sinDireccion.status, 400);
    assert.equal(destinoMalo.status, 400);
  });

  test('queda pendiente hasta que se paga (simulado)', async () => {
    await pedir('/pagos/preferencia', { method: 'POST', body: pedidoDePrueba('t-4') });
    assert.equal((await (await pedir('/pagos/t-4/estado')).json()).estado, 'pendiente');

    await pedir('/pago/simulado/t-4');
    assert.equal((await (await pedir('/pagos/t-4/estado')).json()).estado, 'aprobado');
  });

  test('en efectivo no pasa por Mercado Pago y sale directo', async () => {
    const respuesta = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: { ...pedidoDePrueba('t-efectivo'), metodoPago: 'efectivo' },
    });
    const preferencia = await respuesta.json();

    assert.equal(respuesta.status, 201);
    assert.equal(preferencia.urlCheckout, null);
    assert.equal((await (await pedir('/pagos/t-efectivo/estado')).json()).estado, 'aprobado');
  });

  test('un medio de pago desconocido se rechaza', async () => {
    const respuesta = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: { ...pedidoDePrueba('t-medio'), metodoPago: 'trueque' },
    });
    assert.equal(respuesta.status, 400);
  });

  test('traduce los estados de Mercado Pago', () => {
    assert.equal(traducirEstado('approved'), 'aprobado');
    assert.equal(traducirEstado('rejected'), 'rechazado');
    assert.equal(traducirEstado('in_process'), 'pendiente');
  });

  test('valida la firma del webhook', () => {
    const secreto = 'abc';
    const ts = '1700000000';
    const v1 = crypto
      .createHmac('sha256', secreto)
      .update(`id:123;request-id:req-1;ts:${ts};`)
      .digest('hex');

    const datos = { secreto, idSolicitud: 'req-1', idDato: '123' };
    assert.equal(firmaValida({ ...datos, firma: `ts=${ts},v1=${v1}` }), true);
    assert.equal(firmaValida({ ...datos, firma: `ts=${ts},v1=${'0'.repeat(64)}` }), false);
    assert.equal(firmaValida({ ...datos, firma: undefined }), false);
  });
});

describe('seguimiento', () => {
  const crearAprobado = async (id, extra = {}) => {
    await pedir('/pagos/preferencia', {
      method: 'POST',
      body: { ...pedidoDePrueba(id), ...extra },
    });
    await pedir(`/pago/simulado/${id}`);
  };

  test('simula las etapas a partir de la aprobación', async () => {
    await crearAprobado('t-5');
    const inicio = Date.now();

    assert.equal(seguimientoDe('t-5', inicio).estado, 'recibido');
    const enCamino = seguimientoDe('t-5', inicio + TIEMPOS.recibido + TIEMPOS.preparacion + 1000);
    assert.equal(enCamino.estado, 'enCamino');
    assert.ok(enCamino.repartidor.lat < 0 && enCamino.minutosEstimados > 0);
    const total = TIEMPOS.recibido + TIEMPOS.preparacion + TIEMPOS.viaje;
    assert.equal(seguimientoDe('t-5', inicio + total + 1000).estado, 'entregado');
  });

  test('con la simulación apagada no inventa un repartidor', async () => {
    await crearAprobado('t-sin-simular');
    const muchoDespues = Date.now() + 60 * 60 * 1000;

    const seguimiento = seguimientoDe('t-sin-simular', muchoDespues, { simularReparto: false });

    assert.equal(seguimiento.estado, 'enPreparacion');
    assert.equal(seguimiento.repartidor, undefined);
  });

  test('el destino del mapa es el que marcó el cliente', async () => {
    const destino = { lat: -32.9, lng: -68.85 };
    await crearAprobado('t-destino', { destino });

    const enCamino = seguimientoDe('t-destino', Date.now() + TIEMPOS.recibido + TIEMPOS.preparacion + 1000);
    assert.deepEqual(enCamino.destino, destino);
  });

  test('usa la posición real que manda el repartidor (con sesión)', async () => {
    await crearAprobado('t-6');
    const posicion = { pedidoId: 't-6', lat: -32.885, lng: -68.84, nombre: 'Male' };

    const sinSesion = await pedir('/repartidores/posicion', { method: 'POST', body: posicion });
    assert.equal(sinSesion.status, 401);

    const conSesion = await pedir('/repartidores/posicion', {
      method: 'POST',
      body: posicion,
      headers: conToken(tokenRepartidor),
    });
    assert.equal(conSesion.status, 204);

    const seguimiento = await (await pedir('/pedidos/t-6/seguimiento')).json();
    assert.equal(seguimiento.estado, 'enCamino');
    assert.equal(seguimiento.repartidor.nombre, 'Male');
    assert.ok(seguimiento.minutosEstimados >= 1);
  });

  test('el repartidor ve lo pendiente y al entregar desaparece', async () => {
    await crearAprobado('t-7', { direccion: 'Belgrano 55' });
    const headers = conToken(tokenRepartidor);
    const lista = async () =>
      (await (await pedir('/repartidores/pedidos', { headers })).json()).find((p) => p.id === 't-7');

    assert.equal((await pedir('/repartidores/pedidos')).status, 401);
    const pendiente = await lista();
    assert.equal(pendiente.direccion, 'Belgrano 55');
    assert.deepEqual(pendiente.productos, ['2 × Yerba mate 1kg']);

    const entregado = await pedir('/pedidos/t-7/entregado', { method: 'POST', headers });
    assert.equal(entregado.status, 204);
    assert.equal(await lista(), undefined);
    assert.equal((await (await pedir('/pedidos/t-7/seguimiento')).json()).estado, 'entregado');
  });
});

describe('IA', () => {
  const headersDueno = () => conToken(tokenDueno);

  test('sin clave de Gemini devuelve una etiqueta de ejemplo', async () => {
    const respuesta = await pedir('/ia/etiqueta', {
      method: 'POST',
      headers: headersDueno(),
      body: { imagenBase64: Buffer.from('foto').toString('base64'), tipo: 'image/jpeg' },
    });
    const etiqueta = await respuesta.json();
    assert.equal(respuesta.status, 200);
    assert.ok(etiqueta.nombre.length > 0 && etiqueta.precioSugerido > 0);
  });

  test('solo la puede usar el dueño', async () => {
    const respuesta = await pedir('/ia/etiqueta', {
      method: 'POST',
      body: { imagenBase64: 'x', tipo: 'image/jpeg' },
    });
    assert.equal(respuesta.status, 401);
  });

  test('rechaza pedidos sin foto', async () => {
    const respuesta = await pedir('/ia/etiqueta', {
      method: 'POST',
      headers: headersDueno(),
      body: {},
    });
    assert.equal(respuesta.status, 400);
  });

  test('limpia lo que devuelve la IA', () => {
    const limpia = normalizar({ nombre: '  Yerba  ', categoria: 'Joyería', precioSugerido: '-5' });
    assert.equal(limpia.nombre, 'Yerba');
    assert.equal(limpia.categoria, 'Otros');
    assert.equal(limpia.precioSugerido, 0);
  });
});

// Va al final: reabrir la base cambia la que usan las pruebas anteriores.
describe('base de datos', () => {
  test('los datos sobreviven a un reinicio del servidor', () => {
    const carpeta = fs.mkdtempSync(path.join(os.tmpdir(), 'freshmarket-'));
    const ruta = path.join(carpeta, 'prueba.db');
    try {
      abrirBd(ruta);
      const { id } = agregarProducto({ nombre: 'Persistente', precio: 500 });

      // "Reinicio": se cierra y se vuelve a abrir el mismo archivo.
      const bd = abrirBd(ruta);
      assert.equal(buscarProducto(id).nombre, 'Persistente');
      assert.equal(bd.prepare('SELECT COUNT(*) AS c FROM productos').get().c, 9);
    } finally {
      abrirBd(':memory:');
      fs.rmSync(carpeta, { recursive: true, force: true });
    }
  });
});
