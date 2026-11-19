import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/posicion.dart';
import '../../domain/models/recorrido.dart';
import 'api_client.dart';

/// Calcula el camino por las calles entre dos puntos.
abstract interface class RutaService {
  Future<Recorrido> rutaEntre(Posicion desde, Posicion hasta);
}

/// Pide la ruta a OSRM (el ruteador libre de OpenStreetMap): gratis y sin
/// clave, igual que el mapa.
///
/// Primero prueba el perfil de bicicleta del servidor de FOSSGIS (respeta
/// ciclovías y contramanos); si no responde, el servidor de demostración de
/// OSRM. Devuelve los puntos de la calle, en orden, desde el almacén hasta
/// la casa.
class RutaServiceOsrm implements RutaService {
  RutaServiceOsrm({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  static const _limite = Duration(seconds: 8);
  static const _agente = 'FreshMarket/1.1 (app academica ITU Mendoza)';

  /// Servidores a probar, en orden: (host, ruta base).
  static const _servidores = [
    ('routing.openstreetmap.de', '/routed-bike/route/v1/driving/'),
    ('router.project-osrm.org', '/route/v1/bicycle/'),
  ];

  @override
  Future<Recorrido> rutaEntre(Posicion desde, Posicion hasta) async {
    Object? ultimoError;
    for (final (host, base) in _servidores) {
      try {
        return await _pedir(host, base, desde, hasta);
      } on Exception catch (error) {
        ultimoError = error;
      }
    }
    throw ultimoError ?? const ApiException(0, 'sin ruta');
  }

  Future<Recorrido> _pedir(
    String host,
    String base,
    Posicion desde,
    Posicion hasta,
  ) async {
    // OSRM pide las coordenadas como longitud,latitud.
    final tramo = '${desde.longitud},${desde.latitud};'
        '${hasta.longitud},${hasta.latitud}';
    final url = Uri.https(host, '$base$tramo', {
      'overview': 'full',
      'geometries': 'geojson',
    });
    final respuesta = await _cliente
        .get(url, headers: {'User-Agent': _agente}).timeout(_limite);
    if (respuesta.statusCode != 200) {
      throw ApiException(respuesta.statusCode, respuesta.body);
    }
    return leerRespuesta(jsonDecode(respuesta.body), desde, hasta);
  }

  /// Convierte la respuesta de OSRM en un [Recorrido]. Empieza en [desde]
  /// y termina en [hasta] exactos (OSRM los "pega" a la calle más cercana).
  static Recorrido leerRespuesta(
    Object? datos,
    Posicion desde,
    Posicion hasta,
  ) {
    if (datos is! Map<String, dynamic> || datos['code'] != 'Ok') {
      throw const FormatException('OSRM no encontró una ruta.');
    }
    final rutas = datos['routes'];
    if (rutas is! List || rutas.isEmpty) {
      throw const FormatException('OSRM no devolvió rutas.');
    }
    final geometria = (rutas.first as Map<String, dynamic>)['geometry'];
    final coordenadas =
        geometria is Map<String, dynamic> ? geometria['coordinates'] : null;
    if (coordenadas is! List || coordenadas.length < 2) {
      throw const FormatException('La ruta no tiene puntos.');
    }
    final puntos = [
      desde,
      for (final par in coordenadas)
        if (par is List && par.length >= 2)
          Posicion(
            latitud: (par[1] as num).toDouble(),
            longitud: (par[0] as num).toDouble(),
          ),
      hasta,
    ];
    return Recorrido(puntos);
  }
}

/// Línea recta: para las pruebas y para cuando no hay internet.
class RutaServiceRecta implements RutaService {
  const RutaServiceRecta();

  @override
  Future<Recorrido> rutaEntre(Posicion desde, Posicion hasta) async =>
      Recorrido.recto(desde, hasta);
}
