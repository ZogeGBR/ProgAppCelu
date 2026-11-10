import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Si el celular tiene alguna red (Wi-Fi o datos). Evento del sistema que
/// llega por un plugin con Stream (teoría, unidad 13).
///
/// Ojo: tener red NO es tener internet (un Wi-Fi que pide login). Por eso
/// esto solo sirve para AVISAR; el manejo de errores de cada llamada
/// (timeout, reintento) sigue siendo el que decide.
abstract interface class ConectividadService {
  /// Estado actual (Future: se pregunta una vez).
  Future<bool> hayRed();

  /// Cada cambio (Stream: avisa cada vez que se conecta o se desconecta).
  Stream<bool> get cambios;
}

class ConectividadServicePlus implements ConectividadService {
  ConectividadServicePlus({Connectivity? conectividad})
      : _conectividad = conectividad ?? Connectivity();

  final Connectivity _conectividad;

  @override
  Future<bool> hayRed() async =>
      _algunaRed(await _conectividad.checkConnectivity());

  @override
  Stream<bool> get cambios =>
      _conectividad.onConnectivityChanged.map(_algunaRed);

  // Devuelve una lista: puede haber Wi-Fi y datos a la vez.
  static bool _algunaRed(List<ConnectivityResult> redes) =>
      redes.any((red) => red != ConnectivityResult.none);
}

/// Para la demo y las pruebas: se le dice cuándo "se corta" la red.
class ConectividadServiceSimulado implements ConectividadService {
  ConectividadServiceSimulado({bool hayRed = true}) : _hayRed = hayRed;

  bool _hayRed;
  final _cambios = StreamController<bool>.broadcast();

  void cambiar({required bool hayRed}) {
    _hayRed = hayRed;
    _cambios.add(hayRed);
  }

  @override
  Future<bool> hayRed() async => _hayRed;

  @override
  Stream<bool> get cambios => _cambios.stream;
}
