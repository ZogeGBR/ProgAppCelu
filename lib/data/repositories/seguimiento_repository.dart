import 'dart:convert';

import '../../domain/models/pedido.dart';
import '../../domain/models/seguimiento_pedido.dart';
import '../services/pedido_local_service.dart';
import '../services/seguimiento_service.dart';

/// El pedido que quedó guardado en el celular y desde cuándo se seguía.
typedef PedidoGuardado = ({Pedido pedido, DateTime desde});

/// Convierte las novedades crudas del reparto en [SeguimientoPedido] y
/// recuerda en el celular qué pedido se está siguiendo.
class SeguimientoRepository {
  SeguimientoRepository({
    required SeguimientoService service,
    PedidoLocalService? guardado,
    DateTime Function() ahora = DateTime.now,
  })  : _service = service,
        _guardado = guardado,
        _ahora = ahora;

  final SeguimientoService _service;
  final PedidoLocalService? _guardado;
  final DateTime Function() _ahora;

  // Se guarda junto al pedido: Pedido.fromJsonLocal ignora esta clave.
  static const _claveDesde = 'seguidoDesde';

  /// [desde]: al retomar un pedido guardado, cuándo se empezó a seguir
  /// (ver [pedidoGuardado]). Sin él, el seguimiento arranca de cero.
  Stream<SeguimientoPedido> seguir(Pedido pedido, {DateTime? desde}) => _service
      .seguirPedido(
        pedido.id,
        destino: pedido.destino?.toJson(),
        desde: desde,
      )
      .map(SeguimientoPedido.fromJson);

  /// Guarda el pedido (y la hora) para poder retomarlo si la app se cierra.
  Future<void> recordar(Pedido pedido) async => _guardado?.guardar(
        jsonEncode({
          ...pedido.toJsonLocal(),
          _claveDesde: _ahora().toIso8601String(),
        }),
      );

  /// El pedido que se estaba siguiendo, o null. Si lo guardado está roto
  /// (por ejemplo, de una versión vieja de la app), se descarta.
  Future<PedidoGuardado?> pedidoGuardado() async {
    final texto = await _guardado?.leer();
    if (texto == null || texto.isEmpty) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      final pedido = Pedido.fromJsonLocal(json);
      final desde = json[_claveDesde] as String?;
      // Guardado por una versión anterior (sin la hora): la del pedido.
      return (
        pedido: pedido,
        desde: desde == null ? pedido.fecha : DateTime.parse(desde),
      );
    } on Object {
      await olvidar();
      return null;
    }
  }

  /// La persona terminó con ese pedido ("Hacer otro pedido").
  Future<void> olvidar() async => _guardado?.borrar();
}
