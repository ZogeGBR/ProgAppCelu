import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el celular el pedido que se está siguiendo.
///
/// Sin esto, si la persona cierra la app (o la abre tocando la
/// notificación "Tu pedido está en camino"), "Mi pedido" aparece vacío
/// aunque el pedido siga en viaje. Igual que el carrito, guarda y lee
/// texto (JSON); pasar el pedido a JSON es trabajo del repositorio.
abstract interface class PedidoLocalService {
  Future<String?> leer();

  Future<void> guardar(String json);

  Future<void> borrar();
}

/// Usa shared_preferences (clave y valor), como el carrito.
class PedidoLocalServicePreferencias implements PedidoLocalService {
  const PedidoLocalServicePreferencias();

  static const _clave = 'pedido_en_curso_v1';

  @override
  Future<String?> leer() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getString(_clave);
  }

  @override
  Future<void> guardar(String json) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_clave, json);
  }

  @override
  Future<void> borrar() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_clave);
  }
}

/// En memoria: para las pruebas (no toca el disco).
class PedidoLocalServiceMemoria implements PedidoLocalService {
  PedidoLocalServiceMemoria([this._guardado]);

  String? _guardado;

  String? get guardado => _guardado;

  @override
  Future<String?> leer() async => _guardado;

  @override
  Future<void> guardar(String json) async => _guardado = json;

  @override
  Future<void> borrar() async => _guardado = null;
}
