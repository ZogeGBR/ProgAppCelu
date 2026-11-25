import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/error_de_foto.dart';

/// Saca una foto con la cámara del celular (o la elige de la galería).
abstract interface class CamaraService {
  /// La foto, o null si la persona canceló.
  /// Si algo falla de verdad, lanza [ErrorDeFoto].
  Future<Uint8List?> tomarFoto({bool deGaleria = false});

  /// Con poca memoria, Android puede cerrar la app mientras la cámara está
  /// abierta: al volver, la app arranca de cero. image_picker guarda esa
  /// foto y la entrega acá. Null si no había nada que recuperar.
  Future<Uint8List?> recuperarPerdida();
}

class CamaraServiceImagePicker implements CamaraService {
  CamaraServiceImagePicker({ImagePicker? selector})
      : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  // Fotos chicas: alcanzan para reconocer el producto y viajan rápido
  // aunque la conexión sea mala (una foto entera pesa entre 3 y 8 MB).
  static const _anchoMaximo = 1024.0;
  static const _calidad = 80;

  @override
  Future<Uint8List?> tomarFoto({bool deGaleria = false}) async {
    final XFile? archivo;
    try {
      archivo = await _selector.pickImage(
        source: deGaleria ? ImageSource.gallery : ImageSource.camera,
        maxWidth: _anchoMaximo,
        imageQuality: _calidad,
      );
    } on PlatformException catch (error) {
      throw ErrorDeFoto(mensajePara(error.code, deGaleria: deGaleria));
    }
    if (archivo == null) return null; // Canceló: no es un error.
    return archivo.readAsBytes();
  }

  @override
  Future<Uint8List?> recuperarPerdida() async {
    // Solo Android cierra la app así; en las demás plataformas no existe.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final respuesta = await _selector.retrieveLostData();
    if (respuesta.isEmpty) return null;
    final archivo = respuesta.file;
    if (archivo == null) return null;
    return archivo.readAsBytes();
  }

  /// Lo que lee la persona según el código de error de la plataforma.
  static String mensajePara(String codigo, {required bool deGaleria}) =>
      switch (codigo) {
        'camera_access_denied' => 'No tenemos permiso para usar la cámara. '
            'Podés darlo en Ajustes > Apps > FreshMarket > Permisos.',
        'photo_access_denied' => 'No tenemos permiso para ver tus fotos. '
            'Podés darlo en Ajustes > Apps > FreshMarket > Permisos.',
        'no_available_camera' => 'Este dispositivo no tiene una cámara '
            'disponible. Probá con una foto guardada.',
        _ => deGaleria
            ? 'No pudimos abrir tus fotos. Probá de nuevo.'
            : 'No pudimos abrir la cámara. Probá de nuevo.',
      };
}
