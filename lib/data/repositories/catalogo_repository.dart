import 'dart:async';

import '../../domain/models/ficha_producto.dart';
import '../../domain/models/producto.dart';
import '../services/catalogo_service.dart';

/// Fuente de verdad del catálogo.
///
/// Convierte los datos crudos de [CatalogoService] en objetos
/// [Producto], los guarda en memoria para no repetir el pedido y
/// reintenta una vez si el servidor no respondió.
///
/// Patrón Observer en la capa de datos: el repositorio es el **sujeto**.
/// Cada vez que el catálogo cambia (se cargó, el dueño cambió un precio,
/// sacó un producto o cargó uno con la foto) publica la lista nueva en
/// [cambios]. "Comprar" y "Mi almacén" se suscriben y se actualizan solas:
/// ninguna pantalla tiene que avisarle a la otra.
class CatalogoRepository {
  CatalogoRepository({required CatalogoService service}) : _service = service;

  final CatalogoService _service;
  List<Producto>? _cache;

  // `sync: true`: los observadores se enteran en el mismo momento en que
  // cambia el dato, no en una vuelta posterior del event loop.
  final _cambios = StreamController<List<Producto>>.broadcast(sync: true);

  /// Emite la lista completa cada vez que el catálogo cambia.
  Stream<List<Producto>> get cambios => _cambios.stream;

  Future<List<Producto>> obtenerProductos({bool forzar = false}) async {
    final cache = _cache;
    if (cache != null && !forzar) return cache;

    final datos = await _conUnReintento(_service.obtenerProductos);
    return _publicar(List<Producto>.unmodifiable(datos.map(Producto.fromJson)));
  }

  /// Guarda en el catálogo el producto que confirmó el dueño.
  Future<Producto> agregarProducto(FichaProducto ficha) async {
    final datos = await _service.guardarProducto(ficha.toJson());
    final producto = Producto.fromJson(datos);
    final cache = _cache;
    if (cache != null) _publicar(List.unmodifiable([...cache, producto]));
    return producto;
  }

  Future<void> cambiarPrecio(String id, double precio) =>
      _actualizar(id, {'precio': precio});

  Future<void> cambiarDisponible(String id, bool disponible) =>
      _actualizar(id, {'disponible': disponible});

  Future<void> eliminar(String id) async {
    await _service.eliminarProducto(id);
    final cache = _cache;
    if (cache == null) return;
    _publicar(
      List.unmodifiable(cache.where((producto) => producto.id != id)),
    );
  }

  Future<void> _actualizar(String id, Map<String, dynamic> cambios) async {
    final datos = await _service.actualizarProducto(id, cambios);
    final actualizado = Producto.fromJson(datos);
    final cache = _cache;
    if (cache == null) return;
    _publicar(
      List.unmodifiable([
        for (final producto in cache)
          producto.id == id ? actualizado : producto,
      ]),
    );
  }

  /// Guarda la lista nueva y avisa a todos los que observan.
  List<Producto> _publicar(List<Producto> productos) {
    _cache = productos;
    _cambios.add(productos);
    return productos;
  }

  Future<T> _conUnReintento<T>(Future<T> Function() pedido) async {
    try {
      return await pedido();
    } on Exception {
      return pedido();
    }
  }

  /// Solo para cerrar la app o terminar una prueba.
  void dispose() => unawaited(_cambios.close());
}
