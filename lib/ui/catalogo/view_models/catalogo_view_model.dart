import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../domain/models/item_carrito.dart';
import '../../../domain/models/producto.dart';
import '../../core/estado_carga.dart';

/// Estado de la pantalla "Comprar": productos, búsqueda y categoría.
///
/// Está en el medio de dos Observer:
/// - **observa** al [CatalogoRepository]: si el dueño cambia un precio en
///   "Mi almacén", la lista de "Comprar" se actualiza sola;
/// - **es observado** por la vista (ListenableBuilder) con notifyListeners().
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel({required CatalogoRepository repositorio})
      : _repositorio = repositorio {
    _suscripcion = repositorio.cambios.listen(_alCambiarCatalogo);
  }

  static const todasLasCategorias = 'Todas';

  final CatalogoRepository _repositorio;
  late final StreamSubscription<List<Producto>> _suscripcion;

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
      final coincideCategoria =
          _categoria == todasLasCategorias || producto.categoria == _categoria;
      final coincideTexto =
          texto.isEmpty || producto.nombre.toLowerCase().contains(texto);
      return coincideCategoria && coincideTexto;
    }).toList();
  }

  /// Para "Volver a pedir": cambia cada producto del pedido viejo por el de
  /// HOY (con el precio del día) y deja afuera lo que ya no se vende o
  /// está sin stock.
  List<ItemCarrito> conPreciosDeHoy(Iterable<ItemCarrito> viejos) => [
        for (final item in viejos)
          for (final producto in _productos)
            if (producto.id == item.producto.id && producto.disponible)
              ItemCarrito(producto: producto, cantidad: item.cantidad),
      ];

  /// Carga el catálogo. También sirve para reintentar después de un error.
  /// La lista nueva llega por [_alCambiarCatalogo] (el repositorio avisa).
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

  /// Lo llama el repositorio (sujeto) cada vez que el catálogo cambia.
  void _alCambiarCatalogo(List<Producto> productos) {
    _productos = productos;
    _estado = EstadoCarga.exito;
    _avisar();
  }

  // Si la app se cerró mientras se esperaba la respuesta, el
  // ViewModel ya no existe y no hay a quién avisar.
  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    unawaited(_suscripcion.cancel());
    super.dispose();
  }
}
