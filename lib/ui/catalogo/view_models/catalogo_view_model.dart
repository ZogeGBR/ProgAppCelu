import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../domain/models/producto.dart';
import '../../core/estado_carga.dart';

/// Estado de la pantalla "Comprar": productos, búsqueda y categoría.
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel({required CatalogoRepository repositorio})
      : _repositorio = repositorio;

  static const todasLasCategorias = 'Todas';

  final CatalogoRepository _repositorio;

  EstadoCarga _estado = EstadoCarga.cargando;
  List<Producto> _productos = const [];
  String _categoria = todasLasCategorias;
  String _busqueda = '';
  bool _descartado = false;

  EstadoCarga get estado => _estado;
  String get categoriaElegida => _categoria;
  String get busqueda => _busqueda;

  List<String> get categorias => [
        todasLasCategorias,
        ...{for (final producto in _productos) producto.categoria},
      ];

  List<Producto> get productosVisibles {
    final texto = _busqueda.trim().toLowerCase();
    return _productos.where((producto) {
      final coincideCategoria = _categoria == todasLasCategorias ||
          producto.categoria == _categoria;
      final coincideTexto =
          texto.isEmpty || producto.nombre.toLowerCase().contains(texto);
      return coincideCategoria && coincideTexto;
    }).toList();
  }

  /// Carga el catálogo. También sirve para reintentar después de un error.
  Future<void> cargar({bool forzar = false}) async {
    _estado = EstadoCarga.cargando;
    _avisar();
    try {
      _productos = await _repositorio.obtenerProductos(forzar: forzar);
      _estado = EstadoCarga.exito;
    } on Exception {
      _estado = EstadoCarga.error;
    }
    _avisar();
  }

  void elegirCategoria(String categoria) {
    _categoria = categoria;
    notifyListeners();
  }

  void buscar(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  // Si la app se cerró mientras se esperaba la respuesta, el
  // ViewModel ya no existe y no hay a quién avisar.
  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
