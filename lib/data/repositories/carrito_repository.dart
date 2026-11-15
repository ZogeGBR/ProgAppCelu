import 'dart:convert';

import '../../domain/models/item_carrito.dart';
import '../services/carrito_local_service.dart';

/// Guarda y recupera el carrito del celular.
///
/// Si lo guardado está roto (por ejemplo, de una versión vieja de la app),
/// se descarta en silencio: es mejor un carrito vacío que una app que no
/// arranca.
class CarritoRepository {
  CarritoRepository({required CarritoLocalService service})
      : _service = service;

  final CarritoLocalService _service;

  Future<void> guardar(List<ItemCarrito> items) => _service.guardar(
        jsonEncode([for (final item in items) item.toJsonLocal()]),
      );

  Future<List<ItemCarrito>> cargar() async {
    final guardado = await _service.leer();
    if (guardado == null || guardado.isEmpty) return const [];
    try {
      final lista = jsonDecode(guardado) as List<dynamic>;
      return List.unmodifiable(
        lista.map(
          (item) => ItemCarrito.fromJsonLocal(item as Map<String, dynamic>),
        ),
      );
    } on Object {
      return const [];
    }
  }
}
