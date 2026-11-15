// Catálogo del almacén, guardado en la base de datos.
import crypto from 'node:crypto';

import { obtenerBd } from './bd.js';

export const CATEGORIAS = [
  'Almacén',
  'Lácteos',
  'Panadería',
  'Verdulería',
  'Bebidas',
  'Limpieza',
  'Otros',
];

const LARGO_NOMBRE = 80;
const LARGO_DESCRIPCION = 200;

export class ErrorDeValidacion extends Error {}

const aProducto = (fila) => ({ ...fila, disponible: fila.disponible === 1 });

export function listarProductos() {
  return obtenerBd().prepare('SELECT * FROM productos ORDER BY rowid').all().map(aProducto);
}

export function buscarProducto(id) {
  const fila = obtenerBd().prepare('SELECT * FROM productos WHERE id = ?').get(String(id));
  return fila ? aProducto(fila) : undefined;
}

function validarNombre(valor) {
  const nombre = String(valor ?? '').trim();
  if (!nombre) throw new ErrorDeValidacion('Falta el nombre del producto.');
  return nombre.slice(0, LARGO_NOMBRE);
}

function validarPrecio(valor) {
  const precio = Number(valor);
  if (!Number.isFinite(precio) || precio <= 0) {
    throw new ErrorDeValidacion('El precio tiene que ser mayor a cero.');
  }
  return Math.round(precio);
}

/** Valida y agrega un producto. Devuelve el producto o lanza un Error. */
export function agregarProducto(datos) {
  const producto = {
    id: `p${crypto.randomUUID()}`,
    nombre: validarNombre(datos?.nombre),
    precio: validarPrecio(datos?.precio),
    categoria: CATEGORIAS.includes(datos?.categoria) ? datos.categoria : 'Otros',
    emoji: typeof datos?.emoji === 'string' && datos.emoji ? datos.emoji : '🛒',
    descripcion: String(datos?.descripcion ?? '').slice(0, LARGO_DESCRIPCION),
  };
  obtenerBd()
    .prepare(
      `INSERT INTO productos (id, nombre, precio, categoria, emoji, descripcion)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .run(
      producto.id,
      producto.nombre,
      producto.precio,
      producto.categoria,
      producto.emoji,
      producto.descripcion,
    );
  return { ...producto, disponible: true };
}

/** Cambia solo lo que venga en [cambios]. Devuelve null si no existe. */
export function actualizarProducto(id, cambios) {
  const actual = buscarProducto(id);
  if (!actual) return null;

  const nombre = cambios?.nombre === undefined ? actual.nombre : validarNombre(cambios.nombre);
  const precio = cambios?.precio === undefined ? actual.precio : validarPrecio(cambios.precio);
  const categoria = CATEGORIAS.includes(cambios?.categoria) ? cambios.categoria : actual.categoria;
  const disponible =
    typeof cambios?.disponible === 'boolean' ? cambios.disponible : actual.disponible;

  obtenerBd()
    .prepare('UPDATE productos SET nombre = ?, precio = ?, categoria = ?, disponible = ? WHERE id = ?')
    .run(nombre, precio, categoria, disponible ? 1 : 0, id);
  return buscarProducto(id);
}

/** Los pedidos viejos no se rompen: guardan su propia copia de los ítems. */
export function eliminarProducto(id) {
  return obtenerBd().prepare('DELETE FROM productos WHERE id = ?').run(String(id)).changes > 0;
}
