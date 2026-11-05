import 'api_client.dart';

/// Lo que hace el repartidor contra el servidor. Devuelve datos crudos.
abstract interface class RepartoService {
  Future<List<Map<String, dynamic>>> obtenerPedidos();

  Future<void> enviarPosicion(Map<String, dynamic> posicion);

  Future<void> marcarEntregado(String pedidoId);
}

class RepartoServiceHttp implements RepartoService {
  const RepartoServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    final datos = await _api.get('/repartidores/pedidos') as List<dynamic>;
    return datos.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> enviarPosicion(Map<String, dynamic> posicion) async {
    await _api.post('/repartidores/posicion', posicion);
  }

  @override
  Future<void> marcarEntregado(String pedidoId) async {
    await _api.post('/pedidos/$pedidoId/entregado', const {});
  }
}

/// Modo demo: un pedido de ejemplo para probar la pantalla sin backend.
///
/// La lista hace de "base de datos del servidor", igual que en
/// CatalogoServiceLocal.
class RepartoServiceSimulado implements RepartoService {
  RepartoServiceSimulado();

  final List<Map<String, dynamic>> _pedidos = [
    {
      'id': 'demo-1',
      'numero': 1001,
      'direccion': 'San Martín 1234, Ciudad de Mendoza',
      'destino': {'lat': -32.8805, 'lng': -68.8335},
      'total': 5300,
      'metodoPago': 'efectivo',
      'productos': ['1 × Yerba mate 1kg', '1 × Leche entera 1L'],
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> obtenerPedidos() async =>
      List.of(_pedidos);

  @override
  Future<void> enviarPosicion(Map<String, dynamic> posicion) async {}

  @override
  Future<void> marcarEntregado(String pedidoId) async {
    _pedidos.removeWhere((pedido) => pedido['id'] == pedidoId);
  }
}
