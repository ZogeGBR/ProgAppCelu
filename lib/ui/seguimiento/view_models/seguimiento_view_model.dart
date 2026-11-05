import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/seguimiento_repository.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/posicion.dart';
import '../../../domain/models/seguimiento_pedido.dart';

/// Estado de la pantalla "Mi pedido": la etapa y el repartidor en el mapa.
class SeguimientoViewModel extends ChangeNotifier {
  SeguimientoViewModel({required SeguimientoRepository repositorio})
      : _repositorio = repositorio;

  final SeguimientoRepository _repositorio;

  Pedido? _pedido;
  SeguimientoPedido? _seguimiento;
  StreamSubscription<SeguimientoPedido>? _suscripcion;
  bool _sinConexion = false;

  Pedido? get pedido => _pedido;
  bool get hayPedido => _pedido != null;
  bool get sinConexion => _sinConexion;
  EstadoPedido get estado => _seguimiento?.estado ?? EstadoPedido.recibido;
  bool get entregado => estado == EstadoPedido.entregado;
  Posicion? get posicionRepartidor => _seguimiento?.posicionRepartidor;
  Posicion? get destino => _seguimiento?.destino;
  String? get nombreRepartidor => _seguimiento?.nombreRepartidor;
  int? get minutosEstimados => _seguimiento?.minutosEstimados;

  /// El mapa se muestra solo mientras la bici está en camino.
  bool get mostrarMapa =>
      estado == EstadoPedido.enCamino && posicionRepartidor != null;

  /// Empieza a seguir un pedido recién pagado.
  void seguir(Pedido pedido) {
    _cancelarSuscripcion();
    _pedido = pedido;
    _seguimiento = const SeguimientoPedido(estado: EstadoPedido.recibido);
    _sinConexion = false;
    _suscripcion = _repositorio
        .seguir(pedido)
        .listen(_alRecibirNovedad, onError: _alFallar);
    notifyListeners();
  }

  /// Cierra el pedido entregado para poder hacer otro.
  void terminar() {
    _cancelarSuscripcion();
    _pedido = null;
    _seguimiento = null;
    notifyListeners();
  }

  void _alRecibirNovedad(SeguimientoPedido novedad) {
    _seguimiento = novedad;
    _sinConexion = false;
    if (novedad.estado == EstadoPedido.entregado) _cancelarSuscripcion();
    notifyListeners();
  }

  // Un corte de señal no termina el seguimiento: se avisa y el
  // servicio sigue consultando.
  void _alFallar(Object error) {
    _sinConexion = true;
    notifyListeners();
  }

  void _cancelarSuscripcion() {
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
  }

  @override
  void dispose() {
    _cancelarSuscripcion();
    super.dispose();
  }
}
