// Funciones que se prenden o apagan desde el servidor (capacidades y
// políticas, chequeo "desde el servidor").
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { crearApp } from '../src/app.js';

let servidor;
let url;

before(async () => {
  servidor = crearApp({
    funcionesApagadas: ['pagoEnEfectivo'],
    geocodificacion: 'simulado',
  }).listen(0);
  await new Promise((resolver) => servidor.once('listening', resolver));
  url = `http://localhost:${servidor.address().port}`;
});

after(() => servidor.close());

test('informa qué funciones están prendidas', async () => {
  const funciones = await (await fetch(`${url}/funciones`)).json();
  assert.deepEqual(funciones, {
    pagoEnEfectivo: false,
    cargaConFoto: true,
    recordatorioCarrito: true,
  });
});

test('si el efectivo está apagado, el servidor lo rechaza igual', async () => {
  const respuesta = await fetch(`${url}/pagos/preferencia`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: 'f-1',
      metodoPago: 'efectivo',
      items: [{ productoId: 'p1', cantidad: 1 }],
      direccion: 'San Martín 100',
    }),
  });
  assert.equal(respuesta.status, 400);
});

test('los otros medios de pago siguen andando', async () => {
  const respuesta = await fetch(`${url}/pagos/preferencia`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: 'f-2',
      metodoPago: 'debito',
      items: [{ productoId: 'p1', cantidad: 1 }],
      direccion: 'San Martín 100',
    }),
  });
  assert.equal(respuesta.status, 201);
});
