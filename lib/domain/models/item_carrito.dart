import 'producto.dart';

/// Un producto dentro del carrito, con la cantidad pedida.
///
/// Es inmutable: para cambiar la cantidad se crea una copia con
/// [copiarCon]. Así un pedido ya armado nunca cambia por accidente.
class ItemCarrito {
  const ItemCarrito({required this.producto, this.cantidad = 1});

  /// Lee un ítem guardado en el celular con [toJsonLocal].
  factory ItemCarrito.fromJsonLocal(Map<String, dynamic> json) => ItemCarrito(
        producto: Producto.fromJson(json['producto'] as Map<String, dynamic>),
        cantidad: json['cantidad'] as int,
      );

  final Producto producto;
  final int cantidad;

  double get subtotal => producto.precio * cantidad;

  ItemCarrito copiarCon({int? cantidad}) =>
      ItemCarrito(producto: producto, cantidad: cantidad ?? this.cantidad);

  /// Para guardar el carrito en el celular: lleva el producto completo.
  Map<String, dynamic> toJsonLocal() => {
        'producto': producto.toJson(),
        'cantidad': cantidad,
      };

  /// Fila de la tabla `carrito` de SQLite (convención de la teoría: toMap
  /// y fromMap). En SQL las columnas van con guion bajo y no hay bool:
  /// `disponible` va como 1 o 0.
  Map<String, Object?> toMap() => {
        'producto_id': producto.id,
        'nombre': producto.nombre,
        'precio': producto.precio,
        'categoria': producto.categoria,
        'emoji': producto.emoji,
        'descripcion': producto.descripcion,
        'disponible': producto.disponible ? 1 : 0,
        'cantidad': cantidad,
      };

  /// Fila de SQLite -> ítem. `as num` sirve si el precio llega como 1500 o
  /// 1500.0 (`as double` fallaría con un entero).
  factory ItemCarrito.fromMap(Map<String, Object?> fila) => ItemCarrito(
        producto: Producto(
          id: fila['producto_id']! as String,
          nombre: fila['nombre']! as String,
          precio: (fila['precio']! as num).toDouble(),
          categoria: fila['categoria']! as String,
          emoji: fila['emoji'] as String? ?? Producto.emojiPorDefecto,
          descripcion: fila['descripcion'] as String? ?? '',
          disponible: fila['disponible'] != 0,
        ),
        cantidad: fila['cantidad']! as int,
      );

  /// Para el backend: solo lo necesario (el precio lo vuelve a calcular él).
  Map<String, dynamic> toJson() => {
        'productoId': producto.id,
        'nombre': producto.nombre,
        'precioUnitario': producto.precio,
        'cantidad': cantidad,
      };
}
