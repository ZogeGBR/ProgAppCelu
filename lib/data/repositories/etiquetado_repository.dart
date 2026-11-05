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

  Future<Uint8List?> tomarFoto({bool deGaleria = false}) =>
      _camara.tomarFoto(deGaleria: deGaleria);

  Future<FichaProducto> armarFicha(Uint8List foto) async {
    final datos = await _etiquetado.analizarFoto(foto);
    return FichaProducto.fromJson(datos);
  }
}
