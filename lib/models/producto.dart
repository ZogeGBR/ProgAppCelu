/// Modelo de datos de un producto del almacén FreshMarket.
///
/// Representa un ítem del inventario de Don Ceferino, con su precio
/// del día (que él cambia seguido, según contó en la entrevista).
class Producto {
  final String id;
  final String nombre;
  final double precio;
  final String categoria;
  final String emoji; // Usamos un emoji como "ícono" simple del producto

  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    required this.emoji,
  });
}

/// Catálogo de ejemplo de FreshMarket.
///
/// En una próxima entrega esto podría venir de una base de datos o
/// una API, pero para esta etapa de la materia lo dejamos como una
/// lista fija en memoria (const), tal como se vio con el ejemplo de
/// _products del apunte de callbacks.
final List<Producto> catalogoFreshMarket = [
  const Producto(
    id: 'p1',
    nombre: 'Fideos guiseros 500g',
    precio: 1200,
    categoria: 'Almacén',
    emoji: '🍝',
  ),
  const Producto(
    id: 'p2',
    nombre: 'Yerba mate 1kg',
    precio: 3800,
    categoria: 'Almacén',
    emoji: '🧉',
  ),
  const Producto(
    id: 'p3',
    nombre: 'Leche entera 1L',
    precio: 1500,
    categoria: 'Lácteos',
    emoji: '🥛',
  ),
  const Producto(
    id: 'p4',
    nombre: 'Pan francés (kg)',
    precio: 2200,
    categoria: 'Panadería',
    emoji: '🥖',
  ),
  const Producto(
    id: 'p5',
    nombre: 'Tomate (kg)',
    precio: 1800,
    categoria: 'Verdulería',
    emoji: '🍅',
  ),
  const Producto(
    id: 'p6',
    nombre: 'Queso cremoso (kg)',
    precio: 6500,
    categoria: 'Lácteos',
    emoji: '🧀',
  ),
  const Producto(
    id: 'p7',
    nombre: 'Gaseosa cola 2.25L',
    precio: 2600,
    categoria: 'Bebidas',
    emoji: '🥤',
  ),
  const Producto(
    id: 'p8',
    nombre: 'Papel higiénico x4',
    precio: 2100,
    categoria: 'Limpieza',
    emoji: '🧻',
  ),
];
