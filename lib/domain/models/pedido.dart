import 'item_carrito.dart';
import 'metodo_pago.dart';
import 'posicion.dart';

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
    this.direccion = '',
    this.destino,
  });

  /// Lee un pedido guardado en el celular con [toJsonLocal].
  factory Pedido.fromJsonLocal(Map<String, dynamic> json) {
    final destino = json['destino'] as Map<String, dynamic>?;
    return Pedido(
      id: json['id'] as String,
      numero: json['numero'] as int,
      items: List.unmodifiable(
        (json['items'] as List<dynamic>).map(
          (item) => ItemCarrito.fromJsonLocal(item as Map<String, dynamic>),
        ),
      ),
      metodoPago: MetodoPago.values.byName(json['metodoPago'] as String),
      fecha: DateTime.parse(json['fecha'] as String),
      direccion: json['direccion'] as String? ?? '',
      destino: destino == null ? null : Posicion.fromJson(destino),
    );
  }

  final String id;
  final int numero;
  final List<ItemCarrito> items;
  final MetodoPago metodoPago;
  final DateTime fecha;

  /// Calle y número, como lo escribió el cliente.
  final String direccion;

  /// El punto que marcó en el mapa. Es opcional.
  final Posicion? destino;

  double get total => items.fold(0, (total, item) => total + item.subtotal);

  int get cantidadProductos =>
      items.fold(0, (total, item) => total + item.cantidad);

  Pedido copiarCon({int? numero, String? direccion, Posicion? destino}) =>
      Pedido(
        id: id,
        numero: numero ?? this.numero,
        items: items,
        metodoPago: metodoPago,
        fecha: fecha,
        direccion: direccion ?? this.direccion,
        destino: destino ?? this.destino,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'items': [for (final item in items) item.toJson()],
        'metodoPago': metodoPago.name,
        'fecha': fecha.toIso8601String(),
        'direccion': direccion,
        if (destino != null) 'destino': destino!.toJson(),
      };

  /// Para guardarlo en el celular: a diferencia de [toJson] (que va al
  /// backend), guarda el producto completo, para poder mostrar el resumen
  /// del pedido sin internet.
  Map<String, dynamic> toJsonLocal() => {
        'id': id,
        'numero': numero,
        'items': [for (final item in items) item.toJsonLocal()],
        'metodoPago': metodoPago.name,
        'fecha': fecha.toIso8601String(),
        'direccion': direccion,
        if (destino != null) 'destino': destino!.toJson(),
      };
}
