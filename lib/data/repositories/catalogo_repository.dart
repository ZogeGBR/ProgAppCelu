import '../../domain/models/ficha_producto.dart';
import '../../domain/models/producto.dart';
import '../services/catalogo_service.dart';

/// Fuente de verdad del catálogo.
///
/// Convierte los datos crudos de [CatalogoService] en objetos
/// [Producto], los guarda en memoria para no repetir el pedido y
/// reintenta una vez si el servidor no respondió.
class CatalogoRepository {
  CatalogoRepository({required CatalogoService service}) : _service = service;

  final CatalogoService _service;
  List<Producto>? _cache;

  Future<List<Producto>> obtenerProductos({bool forzar = false}) async {
    final cache = _cache;
    if (cache != null && !forzar) return cache;

    final datos = await _conUnReintento(_service.obtenerProductos);
    final productos = List<Producto>.unmodifiable(datos.map(Producto.fromJson));
    _cache = productos;
    return productos;
  }

  /// Guarda en el catálogo el producto que confirmó el dueño.
  Future<Producto> agregarProducto(FichaProducto ficha) async {
    final datos = await _service.guardarProducto(ficha.toJson());
    final producto = Producto.fromJson(datos);
    final cache = _cache;
    if (cache != null) _cache = List.unmodifiable([...cache, producto]);
    return producto;
  }

  Future<T> _conUnReintento<T>(Future<T> Function() pedido) async {
    try {
      return await pedido();
    } on Exception {
      return pedido();
    }
  }
}
