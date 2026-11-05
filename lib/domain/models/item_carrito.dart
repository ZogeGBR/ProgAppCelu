import 'producto.dart';

/// Un producto dentro del carrito, con la cantidad pedida.
///
/// Es inmutable: para cambiar la cantidad se crea una copia con
/// [copiarCon]. Así un pedido ya armado nunca cambia por accidente.
class ItemCarrito {
  const ItemCarrito({required this.producto, this.cantidad = 1});

  final Producto producto;
  final int cantidad;

  double get subtotal => producto.precio * cantidad;

  ItemCarrito copiarCon({int? cantidad}) =>
      ItemCarrito(producto: producto, cantidad: cantidad ?? this.cantidad);

  Map<String, dynamic> toJson() => {
        'productoId': producto.id,
        'nombre': producto.nombre,
        'precioUnitario': producto.precio,
        'cantidad': cantidad,
      };
}
