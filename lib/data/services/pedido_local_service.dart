import 'preferencias.dart';

/// Guarda en el celular el pedido que se está siguiendo.
///
/// Sin esto, si la persona cierra la app (o la abre tocando la
/// notificación "Tu pedido está en camino"), "Mi pedido" aparece vacío
/// aunque el pedido siga en viaje. Es UN objeto chico: alcanza con una
/// preferencia que guarda texto (JSON); pasarlo a JSON es trabajo del
/// repositorio.
abstract interface class PedidoLocalService {
  Future<String?> leer();

  Future<void> guardar(String json);

  Future<void> borrar();
}

/// Usa shared_preferences (clave y valor), a través de [Preferencias].
class PedidoLocalServicePreferencias implements PedidoLocalService {
  const PedidoLocalServicePreferencias(this._preferencias);

  final Preferencias _preferencias;

  static const _clave = Preferencias.clavePedidoEnCurso;

  @override
  Future<String?> leer() => _preferencias.leer(_clave);

  @override
  Future<void> guardar(String json) => _preferencias.guardar(_clave, json);

  @override
  Future<void> borrar() => _preferencias.borrar(_clave);
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
