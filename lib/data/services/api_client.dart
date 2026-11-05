import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP mínimo para hablar con el backend de FreshMarket.
///
/// Todas las llamadas tienen un tiempo límite: si el servidor no
/// responde, salta una TimeoutException en lugar de dejar la pantalla
/// cargando para siempre.
class ApiClient {
  ApiClient({
    required this.urlBase,
    http.Client? cliente,
    this.limite = const Duration(seconds: 10),
  }) : _cliente = cliente ?? http.Client();

  final String urlBase;
  final Duration limite;
  final http.Client _cliente;

  Future<dynamic> get(String ruta) async {
    final respuesta =
        await _cliente.get(Uri.parse('$urlBase$ruta')).timeout(limite);
    return _decodificar(respuesta);
  }

  Future<dynamic> post(
    String ruta,
    Map<String, dynamic> cuerpo, {
    Duration? limite,
  }) async {
    final respuesta = await _cliente
        .post(
          Uri.parse('$urlBase$ruta'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(cuerpo),
        )
        .timeout(limite ?? this.limite);
    return _decodificar(respuesta);
  }

  dynamic _decodificar(http.Response respuesta) {
    final esExito = respuesta.statusCode >= 200 && respuesta.statusCode < 300;
    if (!esExito) throw ApiException(respuesta.statusCode, respuesta.body);
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }
}

/// El backend respondió con un código de error (4xx o 5xx).
class ApiException implements Exception {
  const ApiException(this.codigo, this.cuerpo);

  final int codigo;
  final String cuerpo;

  @override
  String toString() => 'ApiException($codigo): $cuerpo';
}
