import 'api_client.dart';

/// Cuentas del almacén (dueño y repartidores).
///
/// - [ingresar] canjea email y contraseña por una sesión. Si no coinciden,
///   lanza [ApiException] con código 401.
/// - [solicitarCodigo] pide que se mande un código de 6 dígitos al email.
///   Responde igual exista o no la cuenta.
/// - [confirmarCodigo] cambia la contraseña. Si el código no sirve, lanza
///   [ApiException] con código 400.
abstract interface class SesionService {
  Future<Map<String, dynamic>> ingresar(String email, String clave);

  Future<void> solicitarCodigo(String email);

  Future<void> confirmarCodigo({
    required String email,
    required String codigo,
    required String claveNueva,
  });
}

class SesionServiceHttp implements SesionService {
  const SesionServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> ingresar(String email, String clave) async {
    return await _api.post('/sesiones', {'email': email, 'clave': clave})
        as Map<String, dynamic>;
  }

  @override
  Future<void> solicitarCodigo(String email) async {
    await _api.post('/recuperacion/solicitar', {'email': email});
  }

  @override
  Future<void> confirmarCodigo({
    required String email,
    required String codigo,
    required String claveNueva,
  }) async {
    await _api.post('/recuperacion/confirmar', {
      'email': email,
      'codigo': codigo,
      'claveNueva': claveNueva,
    });
  }
}

/// Modo demo, sin backend. Las cuentas y el código son públicos a propósito
/// y la pantalla de ingreso los muestra.
///
/// El mapa [_claves] hace de "tabla usuarios del servidor": por eso puede
/// cambiar cuando alguien recupera su contraseña.
class SesionServiceSimulado implements SesionService {
  SesionServiceSimulado();

  static const emailDueno = 'dueno@freshmarket.com';
  static const emailRepartidor = 'repartidor@freshmarket.com';
  static const claveInicial = 'freshmarket';
  static const codigoDemo = '123456';

  final Map<String, String> _claves = {
    emailDueno: claveInicial,
    emailRepartidor: claveInicial,
  };

  @override
  Future<Map<String, dynamic>> ingresar(String email, String clave) async {
    final cuenta = email.trim().toLowerCase();
    if (_claves[cuenta] != clave) {
      throw const ApiException(401, 'Email o contraseña incorrectos.');
    }
    final rol = cuenta == emailDueno ? 'dueno' : 'repartidor';
    return {
      'rol': rol,
      'token': 'demo-$rol',
      'nombre': rol == 'dueno' ? 'Don Ceferino' : 'Tobías',
    };
  }

  @override
  Future<void> solicitarCodigo(String email) async {}

  @override
  Future<void> confirmarCodigo({
    required String email,
    required String codigo,
    required String claveNueva,
  }) async {
    final cuenta = email.trim().toLowerCase();
    if (!_claves.containsKey(cuenta) || codigo != codigoDemo) {
      throw const ApiException(400, 'El código no es correcto.');
    }
    _claves[cuenta] = claveNueva;
  }
}
