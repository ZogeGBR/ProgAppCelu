import '../../domain/models/sesion.dart';
import '../services/api_client.dart';
import '../services/sesion_service.dart';

/// Maneja el ingreso del dueño y del repartidor.
///
/// La sesión vive solo en memoria: al cerrar la app hay que volver a
/// ingresar. Es a propósito, para no dejar la clave abierta en un celular
/// que puede quedar sobre el mostrador.
class SesionRepository {
  SesionRepository({
    required SesionService service,
    void Function(String? token)? alCambiarToken,
  })  : _service = service,
        _alCambiarToken = alCambiarToken;

  final SesionService _service;
  final void Function(String? token)? _alCambiarToken;

  /// Devuelve la sesión, o null si la clave es incorrecta. Un problema de
  /// conexión se propaga como excepción: no es lo mismo que una clave mala.
  Future<Sesion?> ingresar(String clave) async {
    try {
      final sesion = Sesion.fromJson(await _service.ingresar(clave));
      _alCambiarToken?.call(sesion.token);
      return sesion;
    } on ApiException catch (error) {
      if (error.codigo == 401) return null;
      rethrow;
    }
  }

  void salir() => _alCambiarToken?.call(null);
}
