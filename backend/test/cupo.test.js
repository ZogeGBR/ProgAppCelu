// Cupo de pedidos: hasta 100 por día y 100 por minuto (src/cupo.js).
// Las pruebas usan topes chicos y un reloj propio para no esperar un minuto
// ni hacer 100 pedidos.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { crearApp } from '../src/app.js';
import { inicioDelDia, MAX_POR_DIA, MAX_POR_MINUTO } from '../src/cupo.js';

async function levantar(config) {
  const servidor = crearApp({ geocodificacion: 'simulado', ...config }).listen(0);
  await new Promise((resolver) => servidor.once('listening', resolver));
  return { servidor, url: `http://localhost:${servidor.address().port}` };
}

let siguiente = 0;
function pedir(url) {
  siguiente += 1;
  const id = `cupo-${siguiente}`;
  return fetch(`${url}/pagos/preferencia`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id,
      metodoPago: 'debito',
      items: [{ productoId: 'p1', cantidad: 1 }],
      direccion: 'San Martín 100',
    }),
  }).then(async (respuesta) => ({ id, respuesta, cuerpo: await respuesta.json() }));
}

test('por defecto el almacén toma 100 pedidos por día y 100 por minuto', async () => {
  assert.equal(MAX_POR_DIA, 100);
  assert.equal(MAX_POR_MINUTO, 100);
  const { servidor, url } = await levantar({});
  const salud = await (await fetch(`${url}/salud`)).json();
  servidor.close();
  assert.deepEqual(salud.pedidos, { maxPorDia: 100, maxPorMinuto: 100 });
});

test('pasado el tope del minuto se rechaza, y al minuto siguiente hay lugar', async () => {
  let ahora = Date.UTC(2026, 10, 19, 15, 0, 0);
  const { servidor, url } = await levantar({ maxPedidosPorMinuto: 3, reloj: () => ahora });
  try {
    for (let i = 0; i < 3; i += 1) assert.equal((await pedir(url)).respuesta.status, 201);

    const rechazado = await pedir(url);
    assert.equal(rechazado.respuesta.status, 429);
    assert.equal(rechazado.cuerpo.limite, 'porMinuto');
    assert.match(rechazado.cuerpo.error, /en un minuto/);

    ahora += 61 * 1000;
    assert.equal((await pedir(url)).respuesta.status, 201);
  } finally {
    servidor.close();
  }
});

test('con el tope del día cubierto se rechaza hasta mañana', async () => {
  let ahora = Date.now();
  const { servidor, url } = await levantar({ maxPedidosPorDia: 2, reloj: () => ahora });
  try {
    for (let i = 0; i < 2; i += 1) {
      const { id, respuesta } = await pedir(url);
      assert.equal(respuesta.status, 201);
      await fetch(`${url}/pago/simulado/${id}`); // pago aprobado
    }

    const rechazado = await pedir(url);
    assert.equal(rechazado.respuesta.status, 429);
    assert.equal(rechazado.cuerpo.limite, 'porDia');
    assert.match(rechazado.cuerpo.error, /Por hoy/);

    ahora += 24 * 60 * 60 * 1000;
    assert.equal((await pedir(url)).respuesta.status, 201);
  } finally {
    servidor.close();
  }
});

test('un pago abandonado no ocupa lugar en el día', async () => {
  const { servidor, url } = await levantar({ maxPedidosPorDia: 1 });
  try {
    // Dos pedidos sin pagar: ninguno se aprobó, así que el día sigue libre.
    assert.equal((await pedir(url)).respuesta.status, 201);
    assert.equal((await pedir(url)).respuesta.status, 201);
  } finally {
    servidor.close();
  }
});

test('el día empieza a las 00:00 de Argentina, no de Londres', () => {
  // 15/11 a las 23:00 en Argentina = 16/11 a las 02:00 UTC.
  const ahora = Date.UTC(2026, 10, 16, 2, 0, 0);
  assert.equal(inicioDelDia(ahora), Date.UTC(2026, 10, 15, 3, 0, 0));
});
