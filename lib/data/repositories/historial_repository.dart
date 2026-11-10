import '../../domain/models/pedido.dart';
import '../../domain/models/pedido_anterior.dart';
import '../services/historial_dao.dart';

/// Los pedidos ya hechos, guardados en el celular.
///
/// Convierte filas de SQLite (Map) en [PedidoAnterior] y aplica la
/// política de cuánto guardar: los últimos [diasAGuardar] días.
class HistorialRepository {
  HistorialRepository({
    required HistorialService service,
    DateTime Function()? reloj,
    this.diasAGuardar = 90,
  })  : _service = service,
        _reloj = reloj ?? DateTime.now;

  final HistorialService _service;
  final DateTime Function() _reloj;
  final int diasAGuardar;

  Future<void> guardar(Pedido pedido) =>
      _service.guardar(PedidoAnterior.desdePedido(pedido).toMap());

  Future<List<PedidoAnterior>> ultimos({int limite = 10}) async {
    final filas = await _service.ultimos(limite: limite);
    return List.unmodifiable(filas.map(PedidoAnterior.fromMap));
  }

  /// Borra lo viejo para que la base no crezca para siempre.
  Future<int> limpiarViejos() => _service.borrarAnterioresA(
        _reloj().subtract(Duration(days: diasAGuardar)),
      );
}
