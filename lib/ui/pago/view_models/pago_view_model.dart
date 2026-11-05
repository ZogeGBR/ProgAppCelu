import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pago_repository.dart';
import '../../../domain/models/metodo_pago.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/resultado_pago.dart';

/// Pasos de la pantalla de pago.
enum PasoPago {
  eligiendo,
  abriendoMercadoPago,
  esperandoConfirmacion,
  aprobado,
  rechazado,
  sinConfirmar,
  error,
}

/// Estado de la pantalla de pago.
///
/// No conoce al carrito ni al seguimiento: recibe dos callbacks
/// (patrón de callbacks) para armar el pedido y para avisar que se
/// aprobó. Quien crea la pantalla decide qué hacer en cada caso.
class PagoViewModel extends ChangeNotifier {
  PagoViewModel({
    required PagoRepository repositorio,
    required Pedido Function(MetodoPago metodo) armarPedido,
    required void Function(Pedido pedido) alAprobar,
  })  : _repositorio = repositorio,
        _armarPedido = armarPedido,
        _alAprobar = alAprobar;

  final PagoRepository _repositorio;
  final Pedido Function(MetodoPago metodo) _armarPedido;
  final void Function(Pedido pedido) _alAprobar;

  MetodoPago? _metodo;
  PasoPago _paso = PasoPago.eligiendo;
  Pedido? _pedido;
  StreamSubscription<ResultadoPago>? _suscripcion;
  bool _descartado = false;

  MetodoPago? get metodoElegido => _metodo;
  PasoPago get paso => _paso;
  Pedido? get pedido => _pedido;

  bool get puedePagar => _metodo != null && _paso == PasoPago.eligiendo;

  bool get estaOcupado =>
      _paso == PasoPago.abriendoMercadoPago ||
      _paso == PasoPago.esperandoConfirmacion;

  void elegirMetodo(MetodoPago metodo) {
    if (estaOcupado) return;
    _metodo = metodo;
    notifyListeners();
  }

  Future<void> pagar() async {
    final metodo = _metodo;
    if (metodo == null || estaOcupado) return;

    final pedido = _armarPedido(metodo);
    _pedido = pedido;
    _cambiarPaso(PasoPago.abriendoMercadoPago);

    try {
      await _repositorio.iniciarPago(pedido);
    } on Exception {
      _cambiarPaso(PasoPago.error);
      return;
    }
    if (_descartado) return;

    _cambiarPaso(PasoPago.esperandoConfirmacion);
    _suscripcion = _repositorio.seguirEstado(pedido.id).listen(
          _alRecibirResultado,
          // Una consulta que falla no define nada: se sigue esperando.
          onError: (Object _) {},
          onDone: _alTerminarEspera,
        );
  }

  /// La persona volvió sin pagar o quiere elegir otro medio.
  void volverAElegir() {
    _cancelarEspera();
    _cambiarPaso(PasoPago.eligiendo);
  }

  void _alRecibirResultado(ResultadoPago resultado) {
    if (resultado == ResultadoPago.pendiente) return;
    _cancelarEspera();
    if (resultado == ResultadoPago.aprobado) {
      _alAprobar(_pedido!);
      _cambiarPaso(PasoPago.aprobado);
    } else {
      _cambiarPaso(PasoPago.rechazado);
    }
  }

  void _alTerminarEspera() {
    if (_paso == PasoPago.esperandoConfirmacion) {
      _cambiarPaso(PasoPago.sinConfirmar);
    }
  }

  void _cambiarPaso(PasoPago paso) {
    _paso = paso;
    if (!_descartado) notifyListeners();
  }

  void _cancelarEspera() {
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
  }

  @override
  void dispose() {
    _descartado = true;
    _cancelarEspera();
    super.dispose();
  }
}
