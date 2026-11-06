import 'package:flutter/foundation.dart';

import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/sesion.dart';

enum EstadoIngreso { esperando, ingresando, datosIncorrectos, sinConexion }

/// Quién está usando la app. Sin sesión, es un cliente.
class SesionViewModel extends ChangeNotifier {
  SesionViewModel({required SesionRepository repositorio})
      : _repositorio = repositorio;

  final SesionRepository _repositorio;

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
      _sesion = await _repositorio.ingresar(emailLimpio, clave);
      _cambiar(
        _sesion == null
            ? EstadoIngreso.datosIncorrectos
            : EstadoIngreso.esperando,
      );
    } on Exception {
      _cambiar(EstadoIngreso.sinConexion);
    }
  }

  void salir() {
    _repositorio.salir();
    _sesion = null;
    _cambiar(EstadoIngreso.esperando);
  }

  void _cambiar(EstadoIngreso estado) {
    _estado = estado;
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
