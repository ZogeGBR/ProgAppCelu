import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Saca una foto con la cámara del celular (o la elige de la galería).
/// Devuelve null si la persona cancela.
abstract interface class CamaraService {
  Future<Uint8List?> tomarFoto({bool deGaleria = false});
}

class CamaraServiceImagePicker implements CamaraService {
  CamaraServiceImagePicker({ImagePicker? selector})
      : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  // Fotos chicas: alcanzan para que la IA reconozca el producto y
  // viajan rápido aunque la conexión sea mala.
  static const _anchoMaximo = 1024.0;
  static const _calidad = 80;

  @override
  Future<Uint8List?> tomarFoto({bool deGaleria = false}) async {
    final archivo = await _selector.pickImage(
      source: deGaleria ? ImageSource.gallery : ImageSource.camera,
      maxWidth: _anchoMaximo,
      imageQuality: _calidad,
    );
    if (archivo == null) return null;
    return archivo.readAsBytes();
  }
}
