import 'estado_pedido.dart';
import 'posicion.dart';

/// Cómo va un pedido en este momento: la etapa y, si ya salió, dónde
/// está el repartidor en bicicleta.
class SeguimientoPedido {
  const SeguimientoPedido({
    required this.estado,
    this.posicionRepartidor,
    this.destino,
    this.nombreRepartidor,
    this.minutosEstimados,
  });

  factory SeguimientoPedido.fromJson(Map<String, dynamic> json) {
    final repartidor = json['repartidor'] as Map<String, dynamic>?;
    final destino = json['destino'] as Map<String, dynamic>?;
    return SeguimientoPedido(
      estado: EstadoPedido.values.byName(json['estado'] as String),
      posicionRepartidor:
          repartidor == null ? null : Posicion.fromJson(repartidor),
      destino: destino == null ? null : Posicion.fromJson(destino),
      nombreRepartidor: repartidor?['nombre'] as String?,
      minutosEstimados: json['minutosEstimados'] as int?,
    );
  }

  final EstadoPedido estado;
  final Posicion? posicionRepartidor;
  final Posicion? destino;
  final String? nombreRepartidor;
  final int? minutosEstimados;
}
