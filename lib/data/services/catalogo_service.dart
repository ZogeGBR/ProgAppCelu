import 'api_client.dart';

/// Fuente de los productos del almacén. Devuelve datos crudos (JSON);
/// convertirlos en [Producto] es trabajo del repositorio.
abstract interface class CatalogoService {
  Future<List<Map<String, dynamic>>> obtenerProductos();

  Future<Map<String, dynamic>> guardarProducto(Map<String, dynamic> datos);

  /// Cambia solo los datos que vengan en [cambios].
  Future<Map<String, dynamic>> actualizarProducto(
    String id,
    Map<String, dynamic> cambios,
  );

  Future<void> eliminarProducto(String id);
}

/// Catálogo servido por el backend de FreshMarket (`/productos`).
class CatalogoServiceHttp implements CatalogoService {
  const CatalogoServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final datos = await _api.get('/productos') as List<dynamic>;
    return datos.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> guardarProducto(
    Map<String, dynamic> datos,
  ) async {
    return await _api.post('/productos', datos) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> actualizarProducto(
    String id,
    Map<String, dynamic> cambios,
  ) async {
    return await _api.put('/productos/$id', cambios) as Map<String, dynamic>;
  }

  @override
  Future<void> eliminarProducto(String id) async {
    await _api.delete('/productos/$id');
  }
}

/// Catálogo de ejemplo para usar la app sin backend (demo y pruebas).
///
/// La lista [_productos] hace de "base de datos del servidor": no es una
/// caché de la app (la caché vive en CatalogoRepository).
class CatalogoServiceLocal implements CatalogoService {
  CatalogoServiceLocal({this.demora = const Duration(milliseconds: 400)});

  final Duration demora;

  final List<Map<String, dynamic>> _productos = [
    {
      'id': 'p1',
      'nombre': 'Fideos guiseros 500g',
      'precio': 1200,
      'categoria': 'Almacén',
      'emoji': '🍝',
    },
    {
      'id': 'p2',
      'nombre': 'Yerba mate 1kg',
      'precio': 3800,
      'categoria': 'Almacén',
      'emoji': '🧉',
    },
    {
      'id': 'p3',
      'nombre': 'Leche entera 1L',
      'precio': 1500,
      'categoria': 'Lácteos',
      'emoji': '🥛',
    },
    {
      'id': 'p4',
      'nombre': 'Pan francés (kg)',
      'precio': 2200,
      'categoria': 'Panadería',
      'emoji': '🥖',
    },
    {
      'id': 'p5',
      'nombre': 'Tomate (kg)',
      'precio': 1800,
      'categoria': 'Verdulería',
      'emoji': '🍅',
    },
    {
      'id': 'p6',
      'nombre': 'Queso cremoso (kg)',
      'precio': 6500,
      'categoria': 'Lácteos',
      'emoji': '🧀',
    },
    {
      'id': 'p7',
      'nombre': 'Gaseosa cola 2.25L',
      'precio': 2600,
      'categoria': 'Bebidas',
      'emoji': '🥤',
    },
    {
      'id': 'p8',
      'nombre': 'Papel higiénico x4',
      'precio': 2100,
      'categoria': 'Limpieza',
      'emoji': '🧻',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    await Future<void>.delayed(demora);
    return List.of(_productos);
  }

  @override
  Future<Map<String, dynamic>> guardarProducto(
    Map<String, dynamic> datos,
  ) async {
    await Future<void>.delayed(demora);
    final nuevo = {...datos, 'id': 'p${_productos.length + 1}'};
    _productos.add(nuevo);
    return nuevo;
  }

  @override
  Future<Map<String, dynamic>> actualizarProducto(
    String id,
    Map<String, dynamic> cambios,
  ) async {
    await Future<void>.delayed(demora);
    final indice = _productos.indexWhere((producto) => producto['id'] == id);
    final actualizado = {..._productos[indice], ...cambios};
    _productos[indice] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarProducto(String id) async {
    await Future<void>.delayed(demora);
    _productos.removeWhere((producto) => producto['id'] == id);
  }
}
