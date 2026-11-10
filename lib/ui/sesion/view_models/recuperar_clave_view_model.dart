import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';

/// Pasos de "¿Olvidaste tu contraseña?".
enum PasoRecuperacion {
  pedirEmail,
  enviandoCodigo,
  cambiarClave,
  guardando,
  lista,
}

/// Qué salió mal, para mostrar un mensaje simple.
enum ErrorRecuperacion {
  ninguno,
  emailInvalido,
  codigoInvalido,
  claveCorta,
  clavesDistintas,
  codigoIncorrecto,
  sinConexion,
}

/// Estado de la recuperación de contraseña: primero se pide el email,
/// después se escribe el código que llegó y la contraseña nueva.
class RecuperarClaveViewModel extends ChangeNotifier {
  RecuperarClaveViewModel({
    required SesionRepository repositorio,
    String email = '',
  })  : _repositorio = repositorio,
        _email = email.trim();

  static const largoMinimoClave = 8;
  static const largoCodigo = 6;

  static final _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _soloDigitos = RegExp(r'^\d+$');

  final SesionRepository _repositorio;

  PasoRecuperacion _paso = PasoRecuperacion.pedirEmail;
  ErrorRecuperacion _error = ErrorRecuperacion.ninguno;
  String _email;
  bool _descartado = false;

  PasoRecuperacion get paso => _paso;
  ErrorRecuperacion get error => _error;
  String get email => _email;
  bool get estaOcupado =>
      _paso == PasoRecuperacion.enviandoCodigo ||
      _paso == PasoRecuperacion.guardando;

  Future<void> enviarCodigo(String email) async {
    final limpio = email.trim();
    if (!_formatoEmail.hasMatch(limpio)) {
      _cambiar(_paso, ErrorRecuperacion.emailInvalido);
      return;
    }
    _email = limpio;
    _cambiar(PasoRecuperacion.enviandoCodigo, ErrorRecuperacion.ninguno);
    try {
      await _repositorio.solicitarCodigo(limpio);
      _cambiar(PasoRecuperacion.cambiarClave, ErrorRecuperacion.ninguno);
    } on Exception {
      _cambiar(PasoRecuperacion.pedirEmail, ErrorRecuperacion.sinConexion);
    }
  }

  Future<void> cambiarClave({
    required String codigo,
    required String claveNueva,
    required String repetida,
  }) async {
    final codigoLimpio = codigo.trim();
    final error = _validar(codigoLimpio, claveNueva, repetida);
    if (error != ErrorRecuperacion.ninguno) {
      _cambiar(_paso, error);
      return;
    }

    _cambiar(PasoRecuperacion.guardando, ErrorRecuperacion.ninguno);
    try {
      final resultado = await _repositorio.cambiarClave(
        email: _email,
        codigo: codigoLimpio,
        claveNueva: claveNueva,
      );
      _cambiar(
        resultado == ResultadoCambioClave.cambiada
            ? PasoRecuperacion.lista
            : PasoRecuperacion.cambiarClave,
        resultado == ResultadoCambioClave.cambiada
            ? ErrorRecuperacion.ninguno
            : ErrorRecuperacion.codigoIncorrecto,
      );
    } on Exception {
      _cambiar(PasoRecuperacion.cambiarClave, ErrorRecuperacion.sinConexion);
    }
  }

  /// Volver a pedir el código (por ejemplo, si no llegó).
  void volverAPedirCodigo() =>
      _cambiar(PasoRecuperacion.pedirEmail, ErrorRecuperacion.ninguno);

  ErrorRecuperacion _validar(String codigo, String clave, String repetida) {
    if (codigo.length != largoCodigo || !_soloDigitos.hasMatch(codigo)) {
      return ErrorRecuperacion.codigoInvalido;
    }
    if (clave.length < largoMinimoClave) return ErrorRecuperacion.claveCorta;
    if (clave != repetida) return ErrorRecuperacion.clavesDistintas;
    return ErrorRecuperacion.ninguno;
  }

  void _cambiar(PasoRecuperacion paso, ErrorRecuperacion error) {
    _paso = paso;
    _error = error;
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
