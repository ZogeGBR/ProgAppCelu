import 'metodo_pago.dart';
import 'posicion.dart';

/// Un pedido visto por el repartidor: a dónde va, qué lleva y si tiene
/// que cobrar al entregar.
class PedidoReparto {
  const PedidoReparto({
    required this.id,
    required this.numero,
    required this.direccion,
    required this.total,
    required this.metodoPago,
    required this.productos,
    this.destino,
  });

  factory PedidoReparto.fromJson(Map<String, dynamic> json) {
    final destino = json['destino'] as Map<String, dynamic>?;
    return PedidoReparto(
      id: json['id'] as String,
      numero: json['numero'] as int,
      direccion: json['direccion'] as String,
      total: (json['total'] as num).toDouble(),
      metodoPago: MetodoPago.values.byName(json['metodoPago'] as String),
      productos: (json['productos'] as List<dynamic>).cast<String>(),
      destino: destino == null ? null : Posicion.fromJson(destino),
    );
  }

  final String id;
  final int numero;
  final String direccion;
  final double total;
  final MetodoPago metodoPago;
  final List<String> productos;
  final Posicion? destino;

  bool get hayQueCobrar => metodoPago == MetodoPago.efectivo;
}
