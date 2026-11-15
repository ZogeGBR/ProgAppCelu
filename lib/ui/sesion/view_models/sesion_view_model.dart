import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/sesion.dart';

enum EstadoIngreso { esperando, ingresando, datosIncorrectos, sinConexion }

/// Quién está usando la app. Sin sesión, es un cliente.
///
/// No guarda la sesión por su cuenta: la **observa** en el
/// [SesionRepository] (patrón Observer), que es la única fuente de verdad.
/// Así, si otra parte de la app cierra la sesión, esta pantalla se entera.
class SesionViewModel extends ChangeNotifier {
  SesionViewModel({required SesionRepository repositorio})
      : _repositorio = repositorio,
        _sesion = repositorio.actual {
    _suscripcion = repositorio.cambios.listen(_alCambiarSesion);
  }

  final SesionRepository _repositorio;
  late final StreamSubscription<Sesion?> _suscripcion;

  Sesion? _sesion;
  EstadoIngreso _estado = EstadoIngreso.esperando;
  bool _descartado = false;

  EstadoIngreso get estado => _estado;
  Rol? get rol => _sesion?.rol;
  String get nombre => _sesion?.nombre ?? '';
  bool get haySesion => _sesion != null;
  bool get esDueno => rol == Rol.dueno;
  bool get esRepartidor => rol == Rol.repartidor;

  Future<void> ingresar(String email, String clave) async {
    final emailLimpio = email.trim();
    if (emailLimpio.isEmpty || clave.isEmpty) return;
    if (_estado == EstadoIngreso.ingresando) return;

    _cambiar(EstadoIngreso.ingresando);
    try {
      // La contraseña NO se recorta: un espacio puede ser parte de ella.
      // Si entra, la sesión llega por _alCambiarSesion.
      final sesion = await _repositorio.ingresar(emailLimpio, clave);
      _cambiar(
        sesion == null
            ? EstadoIngreso.datosIncorrectos
            : EstadoIngreso.esperando,
      );
    } on Exception {
      _cambiar(EstadoIngreso.sinConexion);
    }
  }

  void salir() => _repositorio.salir();

  void _alCambiarSesion(Sesion? sesion) {
    _sesion = sesion;
    if (sesion == null) _estado = EstadoIngreso.esperando;
    _avisar();
  }

  void _cambiar(EstadoIngreso estado) {
    _estado = estado;
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    unawaited(_suscripcion.cancel());
    super.dispose();
  }
}
