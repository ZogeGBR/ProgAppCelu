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

  /// La sesión del dueño o del repartidor. Los clientes no tienen.
  String? token;

  Map<String, String> get _encabezados {
    final token = this.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String ruta) async {
    final respuesta = await _cliente
        .get(Uri.parse('$urlBase$ruta'), headers: _encabezados)
        .timeout(limite);
    return _decodificar(respuesta);
  }

  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo) async {
    final respuesta = await _cliente
        .put(
          Uri.parse('$urlBase$ruta'),
          headers: _encabezados,
          body: jsonEncode(cuerpo),
        )
        .timeout(limite);
    return _decodificar(respuesta);
  }

  Future<dynamic> delete(String ruta) async {
    final respuesta = await _cliente
        .delete(Uri.parse('$urlBase$ruta'), headers: _encabezados)
        .timeout(limite);
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
          headers: _encabezados,
          body: jsonEncode(cuerpo),
        )
        .timeout(limite ?? this.limite);
    return _decodificar(respuesta);
  }

  dynamic _decodificar(http.Response respuesta) {
    final esExito = respuesta.statusCode >= 200 && respuesta.statusCode < 300;
    if (!esExito) throw ApiException(respuesta.statusCode, respuesta.body);
    // Las respuestas 204 no traen cuerpo.
    if (respuesta.bodyBytes.isEmpty) return null;
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
