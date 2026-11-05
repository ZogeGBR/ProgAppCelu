import '../../domain/models/pedido_reparto.dart';
import '../../domain/models/posicion.dart';
import '../services/reparto_service.dart';
import '../services/ubicacion_service.dart';

/// Lo que necesita el modo repartidor: sus pedidos y su GPS.
class RepartoRepository {
  RepartoRepository({
    required RepartoService service,
    required UbicacionService ubicacion,
  })  : _service = service,
        _ubicacion = ubicacion;

  /// Es el nombre que ve el cliente en "Mi pedido".
  static const nombreParaElCliente = 'Tu repartidor';

  final RepartoService _service;
  final UbicacionService _ubicacion;

  Future<List<PedidoReparto>> pedidosPendientes() async {
    final datos = await _service.obtenerPedidos();
    return List.unmodifiable(datos.map(PedidoReparto.fromJson));
  }

  Future<PermisoUbicacion> pedirPermiso() => _ubicacion.pedirPermiso();

  Stream<Posicion> seguirUbicacion() => _ubicacion.seguir();

  Future<void> enviarPosicion(String pedidoId, Posicion posicion) {
    return _service.enviarPosicion({
      'pedidoId': pedidoId,
      ...posicion.toJson(),
      'nombre': nombreParaElCliente,
    });
  }

  Future<void> marcarEntregado(String pedidoId) =>
      _service.marcarEntregado(pedidoId);
}
