import 'dart:async';

import '../../domain/models/funciones.dart';
import '../services/funciones_service.dart';

/// Pide al servidor qué funciones están prendidas.
///
/// Política ante errores: si el servidor tarda más de [limite] o falla, se
/// sigue con [Funciones.porDefecto]. La app nunca queda trabada en el
/// arranque por esto.
class FuncionesRepository {
  FuncionesRepository({
    required FuncionesService service,
    this.limite = const Duration(seconds: 3),
  }) : _service = service;

  final FuncionesService _service;
  final Duration limite;

  Future<Funciones> cargar() async {
    try {
      final datos = await _service.obtener().timeout(limite);
      return Funciones.fromJson(datos);
    } on TimeoutException {
      return Funciones.porDefecto;
    } on Exception {
      return Funciones.porDefecto;
    }
  }
}
