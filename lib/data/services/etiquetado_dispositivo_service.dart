import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'etiquetado_service.dart';
import 'lector_de_etiqueta.dart';

/// Reconoce el producto EN EL CELULAR, sin internet y sin claves, con ML Kit
/// de Google:
/// - lee el texto del envase (marca, producto, cantidad), y
/// - reconoce qué se ve en la foto ("Fruit", "Bottle", "Bread"...).
///
/// Con eso [LectorDeEtiqueta] arma la ficha. Es la que usa la app de demo;
/// con backend se usa la IA del servidor (Gemini). En los dos casos el
/// precio lo pone el dueño.
class EtiquetadoServiceDispositivo implements EtiquetadoService {
  EtiquetadoServiceDispositivo({this.confianzaMinima = 0.6});

  /// Qué tan seguro tiene que estar el modelo para usar una etiqueta.
  final double confianzaMinima;

  @override
  Future<Map<String, dynamic>> analizarFoto(Uint8List foto) async {
    // ML Kit lee la imagen desde un archivo: se guarda un momento en la
    // carpeta temporal de la app y se borra al terminar.
    final carpeta = await Directory.systemTemp.createTemp('freshmarket_');
    final archivo = File('${carpeta.path}/producto.jpg');
    final lectorDeTexto = TextRecognizer();
    final etiquetador = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: confianzaMinima),
    );
    try {
      await archivo.writeAsBytes(foto, flush: true);
      final imagen = InputImage.fromFilePath(archivo.path);
      final texto = await lectorDeTexto.processImage(imagen);
      final etiquetas = await etiquetador.processImage(imagen);
      return LectorDeEtiqueta.armar(
        lineas: [
          for (final bloque in texto.blocks)
            for (final linea in bloque.lines)
              LineaLeida(
                texto: linea.text,
                alto: linea.boundingBox.height,
                arriba: linea.boundingBox.top,
              ),
        ],
        etiquetas: [for (final etiqueta in etiquetas) etiqueta.label],
      );
    } finally {
      await lectorDeTexto.close();
      await etiquetador.close();
      try {
        await carpeta.delete(recursive: true);
      } on FileSystemException {
        // Si no se pudo borrar, el sistema limpia la carpeta temporal solo.
      }
    }
  }
}
