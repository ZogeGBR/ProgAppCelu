import '../../domain/models/posicion.dart';
import '../services/geocodificacion_service.dart';
import '../services/ubicacion_service.dart';

/// Todo lo que hace falta para marcar dónde entregar un pedido: pasar de un
/// punto del mapa a "calle y número" y saber dónde está el celular.
///
/// Guarda en memoria las direcciones ya consultadas: si la persona toca dos
/// veces el mismo lugar, la segunda vez no se vuelve a preguntar.
class UbicacionEntregaRepository {
  UbicacionEntregaRepository({
    required GeocodificacionService geocodificacion,
    required UbicacionService gps,
  })  : _geocodificacion = geocodificacion,
        _gps = gps;

  final GeocodificacionService _geocodificacion;
  final UbicacionService _gps;
  final Map<String, String> _cache = {};

  // 4 decimales son unos 10 metros: dos toques tan cerca son la misma casa.
  static const _decimales = 4;

  /// La dirección de ese punto, o '' si el punto no tiene calle.
  Future<String> direccionDe(Posicion posicion) async {
    final clave = '${posicion.latitud.toStringAsFixed(_decimales)},'
        '${posicion.longitud.toStringAsFixed(_decimales)}';
    final guardada = _cache[clave];
    if (guardada != null) return guardada;

    final datos = await _geocodificacion.direccionDe(
      posicion.latitud,
      posicion.longitud,
    );
    final direccion = (datos['direccion'] as String? ?? '').trim();
    if (direccion.isNotEmpty) _cache[clave] = direccion;
    return direccion;
  }

  Future<Posicion?> miPosicion() => _gps.posicionActual();
}
