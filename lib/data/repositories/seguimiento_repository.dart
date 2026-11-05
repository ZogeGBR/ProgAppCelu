import '../../domain/models/pedido.dart';
import '../../domain/models/seguimiento_pedido.dart';
import '../services/seguimiento_service.dart';

/// Convierte las novedades crudas del reparto en [SeguimientoPedido].
class SeguimientoRepository {
  SeguimientoRepository({required SeguimientoService service})
      : _service = service;

  final SeguimientoService _service;

  Stream<SeguimientoPedido> seguir(Pedido pedido) => _service
      .seguirPedido(pedido.id, destino: pedido.destino?.toJson())
      .map(SeguimientoPedido.fromJson);
}
