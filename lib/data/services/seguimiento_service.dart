import 'api_client.dart';

/// Fuente de las novedades de un pedido: etapa y posición del
/// repartidor en bicicleta. Emite datos crudos cada vez que algo cambia.
abstract interface class SeguimientoService {
  /// [destino] es el punto que marcó el cliente (`{'lat': ..., 'lng': ...}`),
  /// si marcó alguno.
  Stream<Map<String, dynamic>> seguirPedido(
    String pedidoId, {
    Map<String, dynamic>? destino,
  });
}

/// Consulta el backend cada [intervalo] (`/pedidos/:id/seguimiento`).
///
/// El backend recibe la posición desde el celular del repartidor. Si una
/// consulta falla, el stream emite el error y sigue consultando: un corte
/// de señal no corta el seguimiento.
class SeguimientoServiceHttp implements SeguimientoService {
  const SeguimientoServiceHttp(
    this._api, {
    this.intervalo = const Duration(seconds: 3),
  });

  final ApiClient _api;
  final Duration intervalo;

  @override
  Stream<Map<String, dynamic>> seguirPedido(
    String pedidoId, {
    Map<String, dynamic>? destino,
  }) {
    // El backend ya sabe el destino: se lo mandó la app al crear el pedido.
    return Stream<void>.periodic(intervalo).asyncMap(
      (_) async => await _api.get('/pedidos/$pedidoId/seguimiento')
          as Map<String, dynamic>,
    );
  }
}

/// Simula un reparto en bicicleta por el centro de Mendoza.
///
/// Usa Stream.periodic (y no un async* con Future.delayed) para que al
/// cancelar la suscripción no quede ningún Timer colgado.
class SeguimientoServiceSimulado implements SeguimientoService {
  const SeguimientoServiceSimulado({
    this.intervalo = const Duration(seconds: 2),
    this.pasosEnCamino = 10,
  });

  final Duration intervalo;
  final int pasosEnCamino;

  static const _almacen = (lat: -32.8895, lng: -68.8458);
  static const _cliente = (lat: -32.8805, lng: -68.8335);
  static const _minutosDeViaje = 12;

  @override
  Stream<Map<String, dynamic>> seguirPedido(
    String pedidoId, {
    Map<String, dynamic>? destino,
  }) {
    final punto = destino ?? {'lat': _cliente.lat, 'lng': _cliente.lng};
    // recibido, en preparación, los pasos en camino y entregado.
    final totalEventos = pasosEnCamino + 3;
    return Stream.periodic(
      intervalo,
      (indice) => _evento(indice, punto),
    ).take(totalEventos);
  }

  Map<String, dynamic> _evento(int indice, Map<String, dynamic> destino) {
    if (indice == 0) return {'estado': 'recibido'};
    if (indice == 1) return {'estado': 'enPreparacion'};

    final paso = indice - 2;
    if (paso >= pasosEnCamino) {
      return {'estado': 'entregado', 'destino': destino};
    }
    final avance = paso / (pasosEnCamino - 1);
    return {
      'estado': 'enCamino',
      'repartidor': _repartidorEn(avance, destino),
      'destino': destino,
      'minutosEstimados': ((1 - avance) * _minutosDeViaje).ceil(),
    };
  }

  Map<String, dynamic> _repartidorEn(
    double avance,
    Map<String, dynamic> destino,
  ) {
    final lat = destino['lat'] as double;
    final lng = destino['lng'] as double;
    return {
      'nombre': 'Tobías',
      'lat': _almacen.lat + (lat - _almacen.lat) * avance,
      'lng': _almacen.lng + (lng - _almacen.lng) * avance,
    };
  }
}
