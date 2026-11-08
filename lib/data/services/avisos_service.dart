import 'api_client.dart';

/// Le dice al backend qué avisos quiere recibir este celular.
abstract interface class AvisosService {
  /// El cliente (sin cuenta) se anota para seguir UN pedido.
  Future<void> anotarParaPedido(String pedidoId, String token);

  /// El dueño o el repartidor, al ingresar: avisos de pedidos nuevos.
  Future<void> anotarCuenta(String token);

  /// Al salir: ese celular deja de recibir los avisos del almacén.
  Future<void> olvidarCuenta(String token);
}

class AvisosServiceHttp implements AvisosService {
  const AvisosServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<void> anotarParaPedido(String pedidoId, String token) =>
      _api.post('/pedidos/${Uri.encodeComponent(pedidoId)}/avisos', {
        'token': token,
      });

  @override
  Future<void> anotarCuenta(String token) =>
      _api.post('/dispositivos', {'token': token});

  // No lleva la sesión: cuando se llama, la sesión ya se cerró. Tener el
  // token del celular alcanza para darlo de baja.
  @override
  Future<void> olvidarCuenta(String token) =>
      _api.delete('/dispositivos/${Uri.encodeComponent(token)}');
}

/// En la demo no hay servidor al que avisarle.
class AvisosServiceSimulado implements AvisosService {
  const AvisosServiceSimulado();

  @override
  Future<void> anotarParaPedido(String pedidoId, String token) async {}

  @override
  Future<void> anotarCuenta(String token) async {}

  @override
  Future<void> olvidarCuenta(String token) async {}
}
