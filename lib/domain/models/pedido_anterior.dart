import 'dart:convert';

import 'item_carrito.dart';
import 'metodo_pago.dart';
import 'pedido.dart';

/// Un pedido ya hecho, guardado en el celular (historial).
///
/// Sigue la convención de la teoría para SQLite: [toMap] y [fromMap]
/// (mismo rol que toJson/fromJson, pero con los tipos que acepta SQLite:
/// sin bool ni DateTime, la fecha va como texto ISO).
class PedidoAnterior {
  const PedidoAnterior({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.metodoPago,
    required this.items,
    this.direccion = '',
  });

  factory PedidoAnterior.desdePedido(Pedido pedido) => PedidoAnterior(
        id: pedido.id,
        numero: pedido.numero,
        fecha: pedido.fecha,
        metodoPago: pedido.metodoPago,
        items: pedido.items,
        direccion: pedido.direccion,
      );

  factory PedidoAnterior.fromMap(Map<String, Object?> fila) {
    final items = jsonDecode(fila['items']! as String) as List<dynamic>;
    return PedidoAnterior(
      id: fila['id']! as String,
      numero: fila['numero']! as int,
      fecha: DateTime.parse(fila['fecha']! as String),
      metodoPago: MetodoPago.values.byName(fila['metodo_pago']! as String),
      items: List.unmodifiable(
        items.map(
          (item) => ItemCarrito.fromJsonLocal(item as Map<String, dynamic>),
        ),
      ),
      // Columna agregada en la versión 2 de la base: en filas viejas es null.
      direccion: fila['direccion'] as String? ?? '',
    );
  }

  final String id;
  final int numero;
  final DateTime fecha;
  final MetodoPago metodoPago;
  final List<ItemCarrito> items;
  final String direccion;

  double get total => items.fold(0, (total, item) => total + item.subtotal);

  int get cantidadProductos =>
      items.fold(0, (total, item) => total + item.cantidad);

  Map<String, Object?> toMap() => {
        'id': id,
        'numero': numero,
        'fecha': fecha.toIso8601String(),
        'metodo_pago': metodoPago.name,
        'total': total,
        'items': jsonEncode([for (final item in items) item.toJsonLocal()]),
        'direccion': direccion,
      };
}
