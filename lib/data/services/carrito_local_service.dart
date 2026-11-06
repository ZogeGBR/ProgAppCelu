import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el carrito en el celular, para que no se pierda si la persona
/// cierra la app (o el sistema la cierra para liberar memoria).
///
/// Guarda y lee texto (JSON). Pasar los ítems a JSON es trabajo del
/// repositorio.
abstract interface class CarritoLocalService {
  Future<String?> leer();

  Future<void> guardar(String json);
}

/// Usa shared_preferences: alcanza para datos chicos de clave y valor.
/// Para historial de pedidos con búsquedas haría falta SQLite (sqflite).
class CarritoLocalServicePreferencias implements CarritoLocalService {
  const CarritoLocalServicePreferencias();

  static const _clave = 'carrito_v1';

  @override
  Future<String?> leer() async {
    // getInstance() devuelve siempre la misma instancia (Singleton del
    // paquete): no se abre el archivo cada vez.
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getString(_clave);
  }

  @override
  Future<void> guardar(String json) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_clave, json);
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
