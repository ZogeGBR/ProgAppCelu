import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pago_repository.dart';
import '../../../data/repositories/seguimiento_repository.dart';
import '../../../domain/models/estado_pedido.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/posicion.dart';
import '../../../domain/models/seguimiento_pedido.dart';

/// Estado de la pantalla "Mi pedido": la etapa y el repartidor en el mapa.
///
/// Usa Observer dos veces:
/// - con [pagos], observa los pedidos confirmados y empieza a seguir el
///   nuevo solo, sin que la pantalla de pago lo llame;
/// - se suscribe al Stream del seguimiento: cada novedad del repartidor
///   llega a [_alRecibirNovedad] y se avisa a la vista.
class SeguimientoViewModel extends ChangeNotifier {
  SeguimientoViewModel({
    required SeguimientoRepository repositorio,
    PagoRepository? pagos,
  }) : _repositorio = repositorio {
    _suscripcionPagos = pagos?.pedidosConfirmados.listen(seguir);
  }

  final SeguimientoRepository _repositorio;
  late final StreamSubscription<Pedido>? _suscripcionPagos;

  Pedido? _pedido;
  SeguimientoPedido? _seguimiento;
  StreamSubscription<SeguimientoPedido>? _suscripcion;
  bool _sinConexion = false;
  bool _descartado = false;

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

  /// Retoma el pedido que se estaba siguiendo antes de cerrar la app (se
  /// llama al abrirla). Si ya se está siguiendo otro, no lo pisa.
  Future<void> restaurar() async {
    final Pedido? guardado;
    try {
      guardado = await _repositorio.pedidoGuardado();
    } on Exception {
      return; // Sin pedido guardado: "Mi pedido" arranca vacío.
    }
    if (guardado == null || _pedido != null || _descartado) return;
    _empezar(guardado);
  }

  /// Empieza a seguir un pedido recién pagado y lo guarda en el celular.
  void seguir(Pedido pedido) {
    _empezar(pedido);
    _sinFrenar(_repositorio.recordar(pedido));
  }

  void _empezar(Pedido pedido) {
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
    _sinFrenar(_repositorio.olvidar());
    notifyListeners();
  }

  // Guardar en el celular nunca frena ni rompe el seguimiento.
  void _sinFrenar(Future<void> tarea) {
    unawaited(tarea.catchError((Object _) {}));
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
    _descartado = true;
    unawaited(_suscripcionPagos?.cancel());
    _cancelarSuscripcion();
    super.dispose();
  }
}
