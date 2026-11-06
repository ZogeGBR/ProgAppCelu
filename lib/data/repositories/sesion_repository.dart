import '../../domain/models/sesion.dart';
import '../services/api_client.dart';
import '../services/sesion_service.dart';

/// Resultado de cambiar la contraseña con el código.
enum ResultadoCambioClave { cambiada, codigoIncorrecto }

/// Maneja el ingreso del dueño y del repartidor, y la recuperación de la
/// contraseña.
///
/// La sesión vive solo en memoria: al cerrar la app hay que volver a
/// ingresar. Es a propósito, para no dejar la cuenta abierta en un celular
/// que puede quedar sobre el mostrador.
class SesionRepository {
  SesionRepository({
    required SesionService service,
    void Function(String? token)? alCambiarToken,
  })  : _service = service,
        _alCambiarToken = alCambiarToken;

  final SesionService _service;
  final void Function(String? token)? _alCambiarToken;

  /// Devuelve la sesión, o null si email o contraseña no coinciden. Un
  /// problema de conexión se propaga como excepción: no es lo mismo.
  Future<Sesion?> ingresar(String email, String clave) async {
    try {
      final sesion = Sesion.fromJson(await _service.ingresar(email, clave));
      _alCambiarToken?.call(sesion.token);
      return sesion;
    } on ApiException catch (error) {
      if (error.codigo == 401) return null;
      rethrow;
    }
  }

  void salir() => _alCambiarToken?.call(null);

  Future<void> solicitarCodigo(String email) => _service.solicitarCodigo(email);

  Future<ResultadoCambioClave> cambiarClave({
    required String email,
    required String codigo,
    required String claveNueva,
  }) async {
    try {
      await _service.confirmarCodigo(
        email: email,
        codigo: codigo,
        claveNueva: claveNueva,
      );
      return ResultadoCambioClave.cambiada;
    } on ApiException catch (error) {
      if (error.codigo == 400) return ResultadoCambioClave.codigoIncorrecto;
      rethrow;
    }
  }
}
