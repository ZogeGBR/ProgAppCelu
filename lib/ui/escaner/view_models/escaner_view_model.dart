import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/etiquetado_repository.dart';
import '../../../domain/models/ficha_producto.dart';

/// Pasos de "Cargar producto con foto".
enum PasoEscaner { inicio, analizando, revisando, guardando, guardado, error }

/// Estado de la pantalla del dueño para cargar productos con una foto.
///
/// La IA solo propone: nada se guarda hasta que el dueño toca
/// "Guardar producto".
///
/// No avisa a nadie al guardar: el [CatalogoRepository] publica el
/// catálogo nuevo y "Comprar" y "Mi almacén" lo observan (patrón Observer).
class EscanerViewModel extends ChangeNotifier {
  EscanerViewModel({
    required EtiquetadoRepository etiquetado,
    required CatalogoRepository catalogo,
  })  : _etiquetado = etiquetado,
        _catalogo = catalogo;

  final EtiquetadoRepository _etiquetado;
  final CatalogoRepository _catalogo;

  PasoEscaner _paso = PasoEscaner.inicio;
  Uint8List? _foto;
  FichaProducto? _ficha;
  String? _ultimoGuardado;
  bool _descartado = false;

  PasoEscaner get paso => _paso;
  Uint8List? get foto => _foto;
  FichaProducto? get ficha => _ficha;
  String? get ultimoGuardado => _ultimoGuardado;
  bool get puedeGuardar => _ficha?.estaCompleta ?? false;

  Future<void> sacarFoto({bool deGaleria = false}) async {
    Uint8List? foto;
    try {
      foto = await _etiquetado.tomarFoto(deGaleria: deGaleria);
    } on Exception {
      _cambiarPaso(PasoEscaner.error);
      return;
    }
    if (foto == null) return; // Canceló la cámara: no pasa nada.

    _foto = foto;
    _ficha = null;
    _cambiarPaso(PasoEscaner.analizando);
    try {
      _ficha = await _etiquetado.armarFicha(foto);
      _cambiarPaso(PasoEscaner.revisando);
    } on Exception {
      _cambiarPaso(PasoEscaner.error);
    }
  }

  void cambiarNombre(String nombre) => _editar(nombre: nombre);

  void cambiarCategoria(String categoria) => _editar(categoria: categoria);

  /// Recibe el texto que escribió el dueño ("3.200", "3200", "$3200").
  void cambiarPrecio(String texto) {
    final soloDigitos = texto.replaceAll(RegExp('[^0-9]'), '');
    _editar(precio: double.tryParse(soloDigitos) ?? 0);
  }

  Future<void> guardar() async {
    final ficha = _ficha;
    if (ficha == null || !ficha.estaCompleta) return;

    _cambiarPaso(PasoEscaner.guardando);
    try {
      final producto = await _catalogo.agregarProducto(ficha);
      _ultimoGuardado = producto.nombre;
      _cambiarPaso(PasoEscaner.guardado);
    } on Exception {
      _cambiarPaso(PasoEscaner.error);
    }
  }

  void empezarDeNuevo() {
    _foto = null;
    _ficha = null;
    _cambiarPaso(PasoEscaner.inicio);
  }

  void _editar({String? nombre, String? categoria, double? precio}) {
    final ficha = _ficha;
    if (ficha == null) return;
    _ficha = ficha.copiarCon(
      nombre: nombre,
      categoria: categoria,
      precio: precio,
    );
    notifyListeners();
  }

  void _cambiarPaso(PasoEscaner paso) {
    _paso = paso;
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
