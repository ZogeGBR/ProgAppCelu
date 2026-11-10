import '../services/conectividad_service.dart';

/// Si hay red. `distinct()`: avisa solo cuando CAMBIA (el sistema a veces
/// repite el mismo estado).
class ConectividadRepository {
  ConectividadRepository({required ConectividadService service})
      : _service = service;

  final ConectividadService _service;

  /// Capacidad que tarda (hay que preguntarle al sistema): Future<bool>.
  Future<bool> hayRed() => _service.hayRed();

  Stream<bool> get cambios => _service.cambios.distinct();
}
