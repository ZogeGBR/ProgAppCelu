import 'item_carrito.dart';
import 'metodo_pago.dart';

/// Un pedido armado a partir del carrito.
///
/// Es una "foto" del carrito: guarda sus propios ítems, así que no
/// cambia aunque el carrito se vacíe después. [id] es único y viaja a
/// Mercado Pago como referencia externa; [numero] es el que ve el
/// cliente ("Pedido #1001").
class Pedido {
  const Pedido({
    required this.id,
    required this.numero,
    required this.items,
    required this.metodoPago,
    required this.fecha,
  });

  final String id;
  final int numero;
  final List<ItemCarrito> items;
  final MetodoPago metodoPago;
  final DateTime fecha;

  double get total => items.fold(0, (total, item) => total + item.subtotal);

  int get cantidadProductos =>
      items.fold(0, (total, item) => total + item.cantidad);

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'items': [for (final item in items) item.toJson()],
        'metodoPago': metodoPago.name,
        'fecha': fecha.toIso8601String(),
      };
}
