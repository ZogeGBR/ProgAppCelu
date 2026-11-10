import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pago_repository.dart';
import '../../../domain/models/metodo_pago.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/posicion.dart';
import '../../../domain/models/resultado_pago.dart';
import '../../../domain/politicas/politicas.dart';

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
/// No conoce al carrito ni al seguimiento. Recibe un callback para armar
/// el pedido (patrón de callbacks) y, cuando el pago se aprueba, el
/// [PagoRepository] lo publica: el carrito y "Mi pedido" lo observan
/// (patrón Observer).
class PagoViewModel extends ChangeNotifier {
  PagoViewModel({
    required PagoRepository repositorio,
    required Pedido Function(MetodoPago metodo) armarPedido,
    Politicas? politicas,
  })  : _repositorio = repositorio,
        _armarPedido = armarPedido,
        _politicas = politicas ?? Politicas();

  final PagoRepository _repositorio;
  final Politicas _politicas;

  /// Los medios que se muestran. El efectivo depende de una política que
  /// manda el servidor (ver Politicas.permitePagoEnEfectivo).
  List<MetodoPago> get metodosDisponibles => [
        for (final metodo in MetodoPago.values)
          if (metodo != MetodoPago.efectivo || _politicas.permitePagoEnEfectivo)
            metodo,
      ];
  final Pedido Function(MetodoPago metodo) _armarPedido;

  MetodoPago? _metodo;
  String _direccion = '';
  Posicion? _destino;
  PasoPago _paso = PasoPago.eligiendo;
  Pedido? _pedido;
  StreamSubscription<ResultadoPago>? _suscripcion;
  bool _descartado = false;

  MetodoPago? get metodoElegido => _metodo;
  String get direccion => _direccion;
  Posicion? get destino => _destino;
  bool get faltaDireccion => _direccion.trim().isEmpty;
  bool get esEfectivo => _metodo == MetodoPago.efectivo;
  PasoPago get paso => _paso;
  Pedido? get pedido => _pedido;

  bool get puedePagar =>
      _metodo != null && !faltaDireccion && _paso == PasoPago.eligiendo;

  bool get estaOcupado =>
      _paso == PasoPago.abriendoMercadoPago ||
      _paso == PasoPago.esperandoConfirmacion;

  void elegirMetodo(MetodoPago metodo) {
    if (estaOcupado) return;
    _metodo = metodo;
    notifyListeners();
  }

  void cambiarDireccion(String direccion) {
    _direccion = direccion;
    notifyListeners();
  }

  /// El punto que se marcó en el mapa. Si el mapa encontró la calle, se
  /// completa sola la dirección (la persona la puede corregir después).
  void marcarDestino(Posicion destino, {String direccion = ''}) {
    _destino = destino;
    if (direccion.trim().isNotEmpty) _direccion = direccion.trim();
    notifyListeners();
  }

  Future<void> pagar() async {
    final metodo = _metodo;
    if (metodo == null || !puedePagar) return;

    final armado = _armarPedido(metodo).copiarCon(
      direccion: _direccion.trim(),
      destino: _destino,
    );
    _pedido = armado;
    _cambiarPaso(PasoPago.abriendoMercadoPago);

    final Pedido pedido;
    try {
      pedido = await _repositorio.iniciarPago(armado);
    } on Exception {
      _cambiarPaso(PasoPago.error);
      return;
    }
    if (_descartado) return;
    _pedido = pedido;

    // En efectivo no hay nada que confirmar: se paga al recibir.
    // El repositorio ya lo publicó como confirmado.
    if (metodo == MetodoPago.efectivo) {
      _cambiarPaso(PasoPago.aprobado);
      return;
    }

    _cambiarPaso(PasoPago.esperandoConfirmacion);
    _suscripcion = _repositorio.seguirEstado(pedido).listen(
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
