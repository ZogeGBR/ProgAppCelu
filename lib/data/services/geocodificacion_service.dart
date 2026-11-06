import 'api_client.dart';

/// De un punto del mapa a "calle y número" (geocodificación inversa).
///
/// Devuelve `{'direccion': 'San Martín 1234, Mendoza', 'lat': ..., 'lng': ...}`.
/// `direccion` puede venir vacía si el punto no tiene calle (una plaza).
abstract interface class GeocodificacionService {
  Future<Map<String, dynamic>> direccionDe(double latitud, double longitud);
}

/// Le pregunta a nuestro backend (`/geo/inversa`), que usa Nominatim de
/// OpenStreetMap o Google y guarda las respuestas en su base.
///
/// Se pasa por el backend y no directo desde el celular porque Nominatim
/// permite 1 consulta por segundo POR APLICACIÓN: el backend las ordena y
/// las guarda, y si un día se usa Google, la clave no queda en la app.
class GeocodificacionServiceHttp implements GeocodificacionService {
  const GeocodificacionServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> direccionDe(
    double latitud,
    double longitud,
  ) async {
    return await _api.get('/geo/inversa?lat=$latitud&lng=$longitud')
        as Map<String, dynamic>;
  }
}

/// Dirección inventada pero estable (el mismo punto da la misma calle),
/// para la demo y las pruebas.
class GeocodificacionServiceSimulado implements GeocodificacionService {
  const GeocodificacionServiceSimulado({
    this.demora = const Duration(milliseconds: 300),
  });

  final Duration demora;

  @override
  Future<Map<String, dynamic>> direccionDe(
    double latitud,
    double longitud,
  ) async {
    await Future<void>.delayed(demora);
    final numero = 100 + (latitud * longitud * 1000).abs().round() % 1900;
    return {
      'direccion': 'San Martín $numero, Mendoza',
      'lat': latitud,
      'lng': longitud,
    };
  }
}
