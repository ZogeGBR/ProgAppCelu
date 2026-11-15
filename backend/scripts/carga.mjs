// Prueba de carga: simula N clientes haciendo un pedido al mismo tiempo.
//
//   node scripts/carga.mjs 500
//
// Levanta un servidor aparte con una base temporal y modo de pago simulado.
// Cada cliente hace lo mismo que la app: ve el catálogo, crea el pedido, paga,
// consulta el estado y mira el seguimiento.
//
// Ojo al leer los números: corre todo en la misma PC, sin internet de por medio
// y sin esperar a Mercado Pago. Mide el backend y su base, no el sistema entero.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const clientes = Number(process.argv[2] ?? 500);
const puerto = 3900;
const url = `http://127.0.0.1:${puerto}`;
const raiz = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const carpeta = fs.mkdtempSync(path.join(os.tmpdir(), 'freshmarket-carga-'));

const servidor = spawn(process.execPath, ['src/server.js'], {
  cwd: raiz,
  env: { ...process.env, PORT: String(puerto), RUTA_BD: path.join(carpeta, 'carga.db') },
  stdio: 'ignore',
});

const tiempos = [];
let errores = 0;

async function medir(ruta, opciones) {
  const inicio = performance.now();
  try {
    const respuesta = await fetch(`${url}${ruta}`, opciones);
    await respuesta.arrayBuffer();
    if (!respuesta.ok) errores += 1;
  } catch {
    errores += 1;
  }
  tiempos.push(performance.now() - inicio);
}

async function cliente(indice) {
  const id = `carga-${indice}`;
  await medir('/productos');
  await medir('/pagos/preferencia', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id,
      metodoPago: 'debito',
      direccion: `Calle ${indice}`,
      items: [{ productoId: 'p2', cantidad: 1 }],
    }),
  });
  await medir(`/pago/simulado/${id}`);
  await medir(`/pagos/${id}/estado`);
  await medir(`/pedidos/${id}/seguimiento`);
}

async function esperarServidor() {
  for (let intento = 0; intento < 50; intento += 1) {
    try {
      await fetch(`${url}/salud`);
      return;
    } catch {
      await new Promise((resolver) => setTimeout(resolver, 100));
    }
  }
  throw new Error('El servidor no arrancó.');
}

const percentil = (ordenados, p) => ordenados[Math.floor((ordenados.length - 1) * p)];

try {
  await esperarServidor();
  const inicio = performance.now();
  await Promise.all(Array.from({ length: clientes }, (_, indice) => cliente(indice)));
  const duracion = performance.now() - inicio;

  const ordenados = [...tiempos].sort((a, b) => a - b);
  console.log(`Clientes simultáneos: ${clientes}`);
  console.log(`Peticiones: ${tiempos.length}, con error: ${errores}`);
  console.log(`Duración total: ${(duracion / 1000).toFixed(2)} s`);
  console.log(`Peticiones por segundo: ${Math.round(tiempos.length / (duracion / 1000))}`);
  console.log(
    `Tiempo por petición: mediana ${percentil(ordenados, 0.5).toFixed(0)} ms, ` +
      `p95 ${percentil(ordenados, 0.95).toFixed(0)} ms, ` +
      `máximo ${ordenados[ordenados.length - 1].toFixed(0)} ms`,
  );
} finally {
  servidor.kill();
  await new Promise((resolver) => setTimeout(resolver, 300));
  fs.rmSync(carpeta, { recursive: true, force: true });
}
