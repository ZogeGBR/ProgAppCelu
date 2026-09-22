import 'producto.dart';

/// Representa un producto ya agregado al carrito, junto con la
/// cantidad pedida.
class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}
