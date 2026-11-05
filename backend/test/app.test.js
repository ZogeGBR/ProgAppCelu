// Pruebas del backend en modo simulado (sin claves): node --test
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { after, before, describe, test } from 'node:test';

import { crearApp } from '../src/app.js';
import { normalizar } from '../src/ia.js';
import { firmaValida, traducirEstado } from '../src/pagos.js';
import { seguimientoDe, TIEMPOS } from '../src/seguimiento.js';

let servidor;
let url;

before(async () => {
  servidor = crearApp({ claveRepartidor: 'secreta' }).listen(0);
  await new Promise((resolver) => servidor.once('listening', resolver));
  url = `http://localhost:${servidor.address().port}`;
});

after(() => servidor.close());

const pedir = (ruta, opciones = {}) =>
  fetch(`${url}${ruta}`, {
    ...opciones,
    headers: { 'Content-Type': 'application/json', ...opciones.headers },
    body: opciones.body ? JSON.stringify(opciones.body) : undefined,
  });

const pedidoDePrueba = (id, items = [{ productoId: 'p2', cantidad: 2 }]) => ({
  id,
  numero: 1001,
  metodoPago: 'debito',
  items,
});

describe('catálogo', () => {
  test('devuelve los productos', async () => {
    const productos = await (await pedir('/productos')).json();
    assert.ok(productos.length >= 8);
  });

  test('valida el producto nuevo', async () => {
    const sinPrecio = await pedir('/productos', { method: 'POST', body: { nombre: 'Algo', precio: 0 } });
    assert.equal(sinPrecio.status, 400);

    const creado = await pedir('/productos', {
      method: 'POST',
      body: { nombre: 'Aceite 1.5L', precio: 3200, categoria: 'Inventada' },
    });
    assert.equal(creado.status, 201);
    assert.equal((await creado.json()).categoria, 'Otros');
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

  test('rechaza productos inexistentes y cantidades raras', async () => {
    const inexistente = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: pedidoDePrueba('t-2', [{ productoId: 'nada', cantidad: 1 }]),
    });
    const negativa = await pedir('/pagos/preferencia', {
      method: 'POST',
      body: pedidoDePrueba('t-3', [{ productoId: 'p1', cantidad: -4 }]),
    });
    assert.equal(inexistente.status, 400);
    assert.equal(negativa.status, 400);
  });

  test('queda pendiente hasta que se paga (simulado)', async () => {
    await pedir('/pagos/preferencia', { method: 'POST', body: pedidoDePrueba('t-4') });
    assert.equal((await (await pedir('/pagos/t-4/estado')).json()).estado, 'pendiente');

    await pedir('/pago/simulado/t-4');
    assert.equal((await (await pedir('/pagos/t-4/estado')).json()).estado, 'aprobado');
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
  test('simula las etapas a partir de la aprobación', async () => {
    await pedir('/pagos/preferencia', { method: 'POST', body: pedidoDePrueba('t-5') });
    await pedir('/pago/simulado/t-5');
    const inicio = Date.now();

    assert.equal(seguimientoDe('t-5', inicio).estado, 'recibido');
    const enCamino = seguimientoDe('t-5', inicio + TIEMPOS.recibido + TIEMPOS.preparacion + 1000);
    assert.equal(enCamino.estado, 'enCamino');
    assert.ok(enCamino.repartidor.lat < 0 && enCamino.minutosEstimados > 0);
    const total = TIEMPOS.recibido + TIEMPOS.preparacion + TIEMPOS.viaje;
    assert.equal(seguimientoDe('t-5', inicio + total + 1000).estado, 'entregado');
  });

  test('usa la posición real que manda el repartidor (con clave)', async () => {
    await pedir('/pagos/preferencia', { method: 'POST', body: pedidoDePrueba('t-6') });
    await pedir('/pago/simulado/t-6');
    const posicion = { pedidoId: 't-6', lat: -32.885, lng: -68.84, nombre: 'Male' };

    const sinClave = await pedir('/repartidores/posicion', { method: 'POST', body: posicion });
    assert.equal(sinClave.status, 401);

    const conClave = await pedir('/repartidores/posicion', {
      method: 'POST',
      body: posicion,
      headers: { 'x-clave-repartidor': 'secreta' },
    });
    assert.equal(conClave.status, 204);

    const seguimiento = await (await pedir('/pedidos/t-6/seguimiento')).json();
    assert.equal(seguimiento.estado, 'enCamino');
    assert.equal(seguimiento.repartidor.nombre, 'Male');
  });
});

describe('IA', () => {
  test('sin clave devuelve una etiqueta de ejemplo', async () => {
    const respuesta = await pedir('/ia/etiqueta', {
      method: 'POST',
      body: { imagenBase64: Buffer.from('foto').toString('base64'), tipo: 'image/jpeg' },
    });
    const etiqueta = await respuesta.json();
    assert.equal(respuesta.status, 200);
    assert.ok(etiqueta.nombre.length > 0 && etiqueta.precioSugerido > 0);
  });

  test('rechaza pedidos sin foto', async () => {
    const respuesta = await pedir('/ia/etiqueta', { method: 'POST', body: {} });
    assert.equal(respuesta.status, 400);
  });

  test('limpia lo que devuelve la IA', () => {
    const limpia = normalizar({ nombre: '  Yerba  ', categoria: 'Joyería', precioSugerido: '-5' });
    assert.equal(limpia.nombre, 'Yerba');
    assert.equal(limpia.categoria, 'Otros');
    assert.equal(limpia.precioSugerido, 0);
  });
});
