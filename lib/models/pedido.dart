import 'item_carrito.dart';
import 'metodo_pago.dart';

/// Un pedido ya confirmado y pagado.
///
/// Es una "foto" del carrito en el momento de pagar: guardamos copias
/// de los ítems para que, aunque el carrito se vacíe después, el
/// pedido conserve lo que se compró.
class Pedido {
  final int numero;
  final List<ItemCarrito> items;
  final double total;
  final MetodoPago metodoPago;
  final DateTime fecha;

  const Pedido({
    required this.numero,
    required this.items,
    required this.total,
    required this.metodoPago,
    required this.fecha,
  });

  int get cantidadProductos =>
      items.fold(0, (total, item) => total + item.cantidad);
}
