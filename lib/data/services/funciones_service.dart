import 'api_client.dart';

/// Qué funciones están prendidas en el servidor.
abstract interface class FuncionesService {
  Future<Map<String, dynamic>> obtener();
}

/// GET /funciones del backend.
class FuncionesServiceHttp implements FuncionesService {
  const FuncionesServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> obtener() async =>
      await _api.get('/funciones') as Map<String, dynamic>;
}

/// Demo y pruebas: responde lo que se le pase (por defecto, todo prendido).
class FuncionesServiceSimulado implements FuncionesService {
  const FuncionesServiceSimulado([this.respuesta = const {}]);

  final Map<String, dynamic> respuesta;

  @override
  Future<Map<String, dynamic>> obtener() async => respuesta;
}
