import 'preferencias.dart';

/// Guarda el carrito en el celular, para que no se pierda si la persona
/// cierra la app (o el sistema la cierra para liberar memoria).
///
/// Guarda y lee texto (JSON). Pasar los ítems a JSON es trabajo del
/// repositorio.
abstract interface class CarritoLocalService {
  Future<String?> leer();

  Future<void> guardar(String json);
}

/// Usa shared_preferences (ver Preferencias): alcanza para datos chicos de
/// clave y valor. El historial de pedidos, que es una lista que se ordena
/// y se recorta, va en SQLite (historial_dao.dart).
class CarritoLocalServicePreferencias implements CarritoLocalService {
  const CarritoLocalServicePreferencias();

  static const _clave = Preferencias.claveCarrito;

  @override
  Future<String?> leer() async {
    return const Preferencias().leer(_clave);
  }

  @override
  Future<void> guardar(String json) async {
    await const Preferencias().guardar(_clave, json);
  }
}

/// En memoria: para las pruebas (no toca el disco).
class CarritoLocalServiceMemoria implements CarritoLocalService {
  CarritoLocalServiceMemoria([this._guardado]);

  String? _guardado;

  String? get guardado => _guardado;

  @override
  Future<String?> leer() async => _guardado;

  @override
  Future<void> guardar(String json) async {
    _guardado = json;
  }
}
