import 'dart:convert';

import 'package:http/http.dart' as http;

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

/// Le pregunta directo a Nominatim (OpenStreetMap) desde el celular.
///
/// Es la que usa la app de demo (sin backend propio): así el cuadro de
/// texto muestra la calle REAL del punto que se tocó en el mapa. Nominatim
/// es gratis y no necesita clave; su política pide identificar la app con
/// un User-Agent y no pasar de 1 consulta por segundo (el repositorio ya
/// guarda las direcciones consultadas, y la persona toca el mapa a mano).
///
/// Si no hay internet o Nominatim no responde, tira el error: la pantalla
/// deja escribir la dirección a mano. Nunca inventa una calle.
class GeocodificacionServiceNominatim implements GeocodificacionService {
  GeocodificacionServiceNominatim({http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  static const _limite = Duration(seconds: 8);
  static const _agente = 'FreshMarket/1.1 (app academica ITU Mendoza)';

  @override
  Future<Map<String, dynamic>> direccionDe(
    double latitud,
    double longitud,
  ) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$latitud',
      'lon': '$longitud',
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'es',
      'zoom': '18',
    });
    final respuesta = await _cliente
        .get(url, headers: {'User-Agent': _agente}).timeout(_limite);
    if (respuesta.statusCode != 200) {
      throw ApiException(respuesta.statusCode, respuesta.body);
    }
    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final direccion = datos is Map<String, dynamic>
        ? armarDireccion(datos['address'] as Map<String, dynamic>? ?? {})
        : '';
    return {'direccion': direccion, 'lat': latitud, 'lng': longitud};
  }

  /// "Calle 1234, Barrio" con lo que haya (igual que el backend, geo.js).
  static String armarDireccion(Map<String, dynamic> partes) {
    String? primero(List<String> claves) {
      for (final clave in claves) {
        final valor = partes[clave];
        if (valor is String && valor.trim().isNotEmpty) return valor.trim();
      }
      return null;
    }

    final calle = primero(['road', 'pedestrian', 'footway']);
    final numero = primero(['house_number']);
    final zona = primero(
      ['neighbourhood', 'suburb', 'city', 'town', 'village'],
    );
    final primeraParte = [calle, numero].whereType<String>().join(' ');
    return [primeraParte, zona]
        .whereType<String>()
        .where((parte) => parte.isNotEmpty)
        .join(', ');
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
