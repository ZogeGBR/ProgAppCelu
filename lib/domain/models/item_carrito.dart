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

  /// Para el backend: solo lo necesario (el precio lo vuelve a calcular él).
  Map<String, dynamic> toJson() => {
        'productoId': producto.id,
        'nombre': producto.nombre,
        'precioUnitario': producto.precio,
        'cantidad': cantidad,
      };
}
