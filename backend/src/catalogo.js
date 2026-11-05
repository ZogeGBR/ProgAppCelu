// Catálogo del almacén. En memoria para la demo: al reiniciar el
// servidor se pierden los productos cargados (ver INFORME, "Qué faltaría").

export const CATEGORIAS = [
  'Almacén',
  'Lácteos',
  'Panadería',
  'Verdulería',
  'Bebidas',
  'Limpieza',
  'Otros',
];

const productos = [
  { id: 'p1', nombre: 'Fideos guiseros 500g', precio: 1200, categoria: 'Almacén', emoji: '🍝' },
  { id: 'p2', nombre: 'Yerba mate 1kg', precio: 3800, categoria: 'Almacén', emoji: '🧉' },
  { id: 'p3', nombre: 'Leche entera 1L', precio: 1500, categoria: 'Lácteos', emoji: '🥛' },
  { id: 'p4', nombre: 'Pan francés (kg)', precio: 2200, categoria: 'Panadería', emoji: '🥖' },
  { id: 'p5', nombre: 'Tomate (kg)', precio: 1800, categoria: 'Verdulería', emoji: '🍅' },
  { id: 'p6', nombre: 'Queso cremoso (kg)', precio: 6500, categoria: 'Lácteos', emoji: '🧀' },
  { id: 'p7', nombre: 'Gaseosa cola 2.25L', precio: 2600, categoria: 'Bebidas', emoji: '🥤' },
  { id: 'p8', nombre: 'Papel higiénico x4', precio: 2100, categoria: 'Limpieza', emoji: '🧻' },
];

export function listarProductos() {
  return productos;
}

export function buscarProducto(id) {
  return productos.find((producto) => producto.id === id);
}

/** Valida y agrega un producto. Devuelve el producto o lanza un Error. */
export function agregarProducto(datos) {
  const nombre = String(datos?.nombre ?? '').trim();
  const precio = Number(datos?.precio);
  if (!nombre) throw new ErrorDeValidacion('Falta el nombre del producto.');
  if (!Number.isFinite(precio) || precio <= 0) {
    throw new ErrorDeValidacion('El precio tiene que ser mayor a cero.');
  }

  const producto = {
    id: `p${Date.now()}`,
    nombre: nombre.slice(0, 80),
    precio: Math.round(precio),
    categoria: CATEGORIAS.includes(datos.categoria) ? datos.categoria : 'Otros',
    emoji: typeof datos.emoji === 'string' && datos.emoji ? datos.emoji : '🛒',
    descripcion: String(datos.descripcion ?? '').slice(0, 200),
  };
  productos.push(producto);
  return producto;
}

export class ErrorDeValidacion extends Error {}
