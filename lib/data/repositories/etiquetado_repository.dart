import 'dart:typed_data';

import '../../domain/models/ficha_producto.dart';
import '../services/camara_service.dart';
import '../services/etiquetado_service.dart';

/// Arma la etiqueta de un producto nuevo a partir de una foto.
class EtiquetadoRepository {
  EtiquetadoRepository({
    required CamaraService camara,
    required EtiquetadoService etiquetado,
  })  : _camara = camara,
        _etiquetado = etiquetado;

  final CamaraService _camara;
  final EtiquetadoService _etiquetado;

  /// Null si la persona canceló; [ErrorDeFoto] si falló de verdad.
  Future<Uint8List?> tomarFoto({bool deGaleria = false}) =>
      _camara.tomarFoto(deGaleria: deGaleria);

  /// La foto que quedó sin usar si Android cerró la app con la cámara
  /// abierta (null si no había ninguna).
  Future<Uint8List?> recuperarFotoPerdida() => _camara.recuperarPerdida();

  /// La foto propone nombre, categoría y descripción. El precio NO: lo
  /// pone siempre el dueño (aunque la IA del servidor sugiera uno).
  Future<FichaProducto> armarFicha(Uint8List foto) async {
    final datos = await _etiquetado.analizarFoto(foto);
    return FichaProducto.fromJson(datos).copiarCon(precio: 0);
  }
}
