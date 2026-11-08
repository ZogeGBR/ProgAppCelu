import 'dart:async';

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
///
/// Patrón Observer: el repositorio es el **sujeto** de la sesión. Cuando
/// alguien entra o sale publica la sesión nueva (o null) en [cambios].
/// Lo observan el [ApiClient] (para usar el token), la barra de abajo
/// (qué secciones mostrar), "Mi almacén", el reparto y las notificaciones.
/// Ninguno de ellos se llama entre sí.
class SesionRepository {
  SesionRepository({required SesionService service}) : _service = service;

  final SesionService _service;
  Sesion? _actual;

  // `sync: true`: el token ya está puesto cuando `ingresar` termina, así
  // el primer pedido del dueño ya viaja autenticado.
  final _cambios = StreamController<Sesion?>.broadcast(sync: true);

  /// Emite la sesión nueva al entrar y null al salir.
  Stream<Sesion?> get cambios => _cambios.stream;

  /// La sesión de este momento (null: es un cliente).
  Sesion? get actual => _actual;

  /// Devuelve la sesión, o null si email o contraseña no coinciden. Un
  /// problema de conexión se propaga como excepción: no es lo mismo.
  Future<Sesion?> ingresar(String email, String clave) async {
    try {
      final sesion = Sesion.fromJson(await _service.ingresar(email, clave));
      _publicar(sesion);
      return sesion;
    } on ApiException catch (error) {
      if (error.codigo == 401) return null;
      rethrow;
    }
  }

  void salir() {
    if (_actual == null) return;
    _publicar(null);
  }

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

  void _publicar(Sesion? sesion) {
    _actual = sesion;
    _cambios.add(sesion);
  }

  void dispose() => unawaited(_cambios.close());
}
