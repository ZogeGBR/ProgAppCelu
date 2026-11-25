import '../../domain/models/item_carrito.dart';
import '../services/carrito_local_service.dart';

/// Guarda y recupera el carrito del celular.
///
/// Convierte entre los ítems del dominio y las filas de la tabla `carrito`
/// (toMap / fromMap). El orden de los renglones se guarda en la columna
/// `orden`, que es cosa de la base y no del dominio.
///
/// Si lo guardado está roto (por ejemplo, de una versión vieja de la app),
/// se descarta en silencio: es mejor un carrito vacío que una app que no
/// arranca.
class CarritoRepository {
  CarritoRepository({required CarritoLocalService service})
      : _service = service;

  final CarritoLocalService _service;

  Future<void> guardar(List<ItemCarrito> items) => _service.guardar([
        for (var i = 0; i < items.length; i++) {...items[i].toMap(), 'orden': i},
      ]);

  Future<List<ItemCarrito>> cargar() async {
    try {
      final filas = await _service.leer();
      return List.unmodifiable(filas.map(ItemCarrito.fromMap));
    } on Object {
      return const [];
    }
  }
}
