import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'api_client.dart';

/// Reconoce un producto a partir de una foto y propone su etiqueta.
abstract interface class EtiquetadoService {
  Future<Map<String, dynamic>> analizarFoto(Uint8List foto);
}

/// Manda la foto al backend (`/ia/etiqueta`), que la analiza con Gemini.
///
/// La clave de la IA vive solo en el backend: nunca viaja en la app.
class EtiquetadoServiceHttp implements EtiquetadoService {
  const EtiquetadoServiceHttp(this._api);

  final ApiClient _api;

  static const _limiteAnalisis = Duration(seconds: 30);

  @override
  Future<Map<String, dynamic>> analizarFoto(Uint8List foto) async {
    // Pasar 1 MB de foto a texto base64 es trabajo de CPU: se hace en otro
    // isolate para que la animación de "Mirando la foto..." no se trabe.
    final imagen = await Isolate.run(() => base64Encode(foto));
    final respuesta = await _api.post(
      '/ia/etiqueta',
      {'imagenBase64': imagen, 'tipo': 'image/jpeg'},
      limite: _limiteAnalisis,
    );
    return respuesta as Map<String, dynamic>;
  }
}

/// Respuesta fija para probar el flujo sin backend ni IA.
class EtiquetadoServiceSimulado implements EtiquetadoService {
  const EtiquetadoServiceSimulado({
    this.demora = const Duration(milliseconds: 1500),
  });

  final Duration demora;

  @override
  Future<Map<String, dynamic>> analizarFoto(Uint8List foto) async {
    await Future<void>.delayed(demora);
    return {
      'nombre': 'Aceite de girasol 1.5L',
      'categoria': 'Almacén',
      'precioSugerido': 3200,
      'descripcion': 'Botella de aceite de girasol de litro y medio.',
      'emoji': '🫒',
    };
  }
}
