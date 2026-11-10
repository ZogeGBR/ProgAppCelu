import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/conectividad_repository.dart';

/// Si hay que mostrar el aviso "Sin internet" arriba de todo.
///
/// Observer dos veces: se suscribe al Stream del sistema y avisa a la
/// vista con notifyListeners(). La suscripción se cancela en dispose():
/// olvidarlo es "el error constante de la unidad".
class ConectividadViewModel extends ChangeNotifier {
  ConectividadViewModel({required ConectividadRepository repositorio})
      : _repositorio = repositorio {
    _suscripcion = repositorio.cambios.listen(
      _cambiar,
      // Si el plugin falla, no se inventa un "sin internet".
      onError: (Object _) {},
    );
  }

  final ConectividadRepository _repositorio;
  late final StreamSubscription<bool> _suscripcion;

  bool _hayRed = true;
  bool _descartado = false;

  bool get hayRed => _hayRed;

  /// Pregunta el estado actual (al abrir la app y al volver a ella).
  Future<void> revisar() async {
    try {
      _cambiar(await _repositorio.hayRed());
    } on Exception {
      // Si el sistema no responde, no se muestra un aviso falso.
    }
  }

  void _cambiar(bool hayRed) {
    if (hayRed == _hayRed || _descartado) return;
    _hayRed = hayRed;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    unawaited(_suscripcion.cancel());
    super.dispose();
  }
}
