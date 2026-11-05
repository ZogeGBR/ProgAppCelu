import 'api_client.dart';

/// Canjea la clave del dueño o del repartidor por una sesión.
/// Si la clave no sirve, lanza [ApiException] con código 401.
abstract interface class SesionService {
  Future<Map<String, dynamic>> ingresar(String clave);
}

class SesionServiceHttp implements SesionService {
  const SesionServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> ingresar(String clave) async {
    return await _api.post('/sesiones', {'clave': clave})
        as Map<String, dynamic>;
  }
}

/// Modo demo, sin backend: las claves son públicas a propósito y la
/// pantalla de ingreso las muestra.
class SesionServiceSimulado implements SesionService {
  const SesionServiceSimulado();

  static const claveDueno = 'dueno';
  static const claveRepartidor = 'repartidor';

  @override
  Future<Map<String, dynamic>> ingresar(String clave) async {
    final rol = switch (clave) {
      claveDueno => 'dueno',
      claveRepartidor => 'repartidor',
      _ => throw const ApiException(401, 'Clave incorrecta.'),
    };
    return {'rol': rol, 'token': 'demo-$rol'};
  }
}
