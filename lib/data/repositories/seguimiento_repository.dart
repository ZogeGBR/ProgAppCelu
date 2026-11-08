import 'dart:convert';

import '../../domain/models/pedido.dart';
import '../../domain/models/seguimiento_pedido.dart';
import '../services/pedido_local_service.dart';
import '../services/seguimiento_service.dart';

/// Convierte las novedades crudas del reparto en [SeguimientoPedido] y
/// recuerda en el celular qué pedido se está siguiendo.
class SeguimientoRepository {
  SeguimientoRepository({
    required SeguimientoService service,
    PedidoLocalService? guardado,
  })  : _service = service,
        _guardado = guardado;

  final SeguimientoService _service;
  final PedidoLocalService? _guardado;

  Stream<SeguimientoPedido> seguir(Pedido pedido) => _service
      .seguirPedido(pedido.id, destino: pedido.destino?.toJson())
      .map(SeguimientoPedido.fromJson);

  /// Guarda el pedido para poder retomarlo si la app se cierra.
  Future<void> recordar(Pedido pedido) async =>
      _guardado?.guardar(jsonEncode(pedido.toJsonLocal()));

  /// El pedido que se estaba siguiendo, o null. Si lo guardado está roto
  /// (por ejemplo, de una versión vieja de la app), se descarta.
  Future<Pedido?> pedidoGuardado() async {
    final texto = await _guardado?.leer();
    if (texto == null || texto.isEmpty) return null;
    try {
      return Pedido.fromJsonLocal(jsonDecode(texto) as Map<String, dynamic>);
    } on Object {
      await olvidar();
      return null;
    }
  }

  /// La persona terminó con ese pedido ("Hacer otro pedido").
  Future<void> olvidar() async => _guardado?.borrar();
}
