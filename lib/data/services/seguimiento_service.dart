import 'dart:async';

import '../../domain/models/almacen.dart';
import '../../domain/models/aviso.dart';
import '../../domain/models/posicion.dart';
import '../../domain/models/recorrido.dart';
import 'api_client.dart';
import 'push_service.dart';
import 'ruta_service.dart';

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
/// La bici sale siempre del almacén de Don Ceferino (Gutiérrez 746) y va
/// hasta el punto que marcó el cliente POR LAS CALLES: con [rutas] pide el
/// camino real a OSRM. Mientras la ruta no llega (o si no hay internet) usa
/// la línea recta, así el seguimiento nunca se traba.
///
/// Usa Stream.periodic (y no un async* con Future.delayed) para que al
/// cancelar la suscripción no quede ningún Timer colgado.
///
/// Con [push], hace lo mismo que el backend real: cuando la bici sale y
/// cuando llega, manda una notificación push (simulada).
class SeguimientoServiceSimulado implements SeguimientoService {
  const SeguimientoServiceSimulado({
    this.intervalo = const Duration(seconds: 2),
    this.pasosEnCamino = 10,
    this.push,
    this.rutas,
    this.origen = Almacen.ubicacion,
  });

  final Duration intervalo;
  final int pasosEnCamino;
  final PushServiceSimulado? push;
  final RutaService? rutas;
  final Posicion origen;

  static const _cliente = Posicion(latitud: -32.8805, longitud: -68.8335);

  // Una bici en el centro anda a unos 15 km/h: 250 metros por minuto.
  static const _metrosPorMinuto = 250.0;

  @override
  Stream<Map<String, dynamic>> seguirPedido(
    String pedidoId, {
    Map<String, dynamic>? destino,
  }) {
    final hasta = destino == null ? _cliente : Posicion.fromJson(destino);
    final punto = hasta.toJson();

    // Mientras se pide la ruta por las calles, la bici todavía está en el
    // almacén (recibido y en preparación): cuando sale, ya está.
    var recorrido = Recorrido.recto(origen, hasta);
    final rutas = this.rutas;
    if (rutas != null) {
      unawaited(
        rutas.rutaEntre(origen, hasta).then(
          (ruta) {
            if (ruta.esValido) recorrido = ruta;
          },
          onError: (Object _) {}, // Sin internet: sigue en línea recta.
        ),
      );
    }

    // recibido, en preparación, los pasos en camino y entregado.
    final totalEventos = pasosEnCamino + 3;
    return Stream.periodic(intervalo, (indice) {
      _avisarSiCorresponde(indice, pedidoId);
      return _evento(indice, punto, recorrido);
    }).take(totalEventos);
  }

  // Igual que el backend (avisos.js): un aviso al salir y otro al llegar,
  // no uno por cada posición.
  void _avisarSiCorresponde(int indice, String pedidoId) {
    final push = this.push;
    if (push == null) return;
    if (indice == 2) {
      push.enviar(
        Aviso(
          titulo: 'Tu pedido está en camino',
          cuerpo: 'Tobías ya salió en bici. Seguilo en el mapa.',
          pedidoId: pedidoId,
        ),
      );
    } else if (indice == pasosEnCamino + 2) {
      push.enviar(
        Aviso(
          titulo: 'Tu pedido llegó',
          cuerpo: '¡Que lo disfrutes! Gracias por comprar en el almacén.',
          pedidoId: pedidoId,
        ),
      );
    }
  }

  Map<String, dynamic> _evento(
    int indice,
    Map<String, dynamic> destino,
    Recorrido recorrido,
  ) {
    if (indice == 0) return {'estado': 'recibido'};
    if (indice == 1) return {'estado': 'enPreparacion'};

    final ruta = [for (final punto in recorrido.puntos) punto.toJson()];
    final paso = indice - 2;
    if (paso >= pasosEnCamino) {
      return {'estado': 'entregado', 'destino': destino, 'ruta': ruta};
    }
    final avance = pasosEnCamino == 1 ? 1.0 : paso / (pasosEnCamino - 1);
    final minutosDeViaje =
        (recorrido.largoMetros / _metrosPorMinuto).ceil().clamp(1, 90);
    final posicion = recorrido.puntoEnFraccion(avance);
    return {
      'estado': 'enCamino',
      'repartidor': {'nombre': 'Tobías', ...posicion.toJson()},
      'destino': destino,
      'ruta': ruta,
      // Mientras no llegó, nunca dice "0 min".
      'minutosEstimados':
          ((1 - avance) * minutosDeViaje).ceil().clamp(1, minutosDeViaje),
    };
  }
}
