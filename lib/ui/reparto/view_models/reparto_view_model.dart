import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/repositories/reparto_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/aviso.dart';
import '../../../domain/models/pedido_reparto.dart';
import '../../../domain/models/permiso_ubicacion.dart';
import '../../../domain/models/posicion.dart';
import '../../../domain/models/sesion.dart';

enum PasoReparto {
  cargando,
  eligiendo,
  error,
  repartiendo,
  sinPermiso,
  gpsApagado
}

/// Estado del modo repartidor: qué pedidos hay y, mientras lleva uno,
/// manda su posición para que el cliente lo vea en el mapa.
///
/// Observa (patrón Observer):
/// - la sesión: cuando entra un repartidor carga sus pedidos y cuando la
///   sesión se cierra apaga el GPS. Nadie tiene que acordarse de llamarlo;
/// - los avisos: si llega "Nuevo pedido" mientras elige, la lista se
///   actualiza sola.
class RepartoViewModel extends ChangeNotifier {
  RepartoViewModel({
    required RepartoRepository repositorio,
    SesionRepository? sesion,
    NotificacionesRepository? notificaciones,
  }) : _repositorio = repositorio {
    _suscripciones = [
      if (sesion != null) sesion.cambios.listen(_alCambiarSesion),
      if (notificaciones != null)
        notificaciones.recibidos.listen(_alRecibirAviso),
    ];
  }

  final RepartoRepository _repositorio;
  late final List<StreamSubscription<Object?>> _suscripciones;
  Rol? _rol;

  PasoReparto _paso = PasoReparto.cargando;
  List<PedidoReparto> _pedidos = const [];
  PedidoReparto? _actual;
  Posicion? _posicion;
  bool _sinConexion = false;
  bool _entregando = false;
  StreamSubscription<Posicion>? _suscripcion;
  bool _descartado = false;

  PasoReparto get paso => _paso;
  List<PedidoReparto> get pedidos => _pedidos;
  PedidoReparto? get actual => _actual;
  Posicion? get posicion => _posicion;
  bool get entregando => _entregando;

  /// La última posición no llegó al servidor (se reintenta con la próxima).
  bool get sinConexion => _sinConexion;

  Future<void> cargar() async {
    _cambiar(PasoReparto.cargando);
    try {
      _pedidos = await _repositorio.pedidosPendientes();
      _cambiar(PasoReparto.eligiendo);
    } on Exception {
      _cambiar(PasoReparto.error);
    }
  }

  /// Pide permiso de ubicación y empieza a mandar la posición.
  Future<void> empezar(PedidoReparto pedido) async {
    final PermisoUbicacion permiso;
    try {
      permiso = await _repositorio.pedirPermiso();
    } on Exception {
      _cambiar(PasoReparto.sinPermiso);
      return;
    }
    if (_descartado) return;

    switch (permiso) {
      case PermisoUbicacion.denegado:
        _cambiar(PasoReparto.sinPermiso);
      case PermisoUbicacion.gpsApagado:
        _cambiar(PasoReparto.gpsApagado);
      case PermisoUbicacion.concedido:
        _actual = pedido;
        _posicion = null;
        _sinConexion = false;
        _cancelarGps();
        _suscripcion = _repositorio.seguirUbicacion().listen(
              _alMoverse,
              onError: (Object _) => _marcarSinConexion(),
            );
        _cambiar(PasoReparto.repartiendo);
    }
  }

  Future<void> entregar() async {
    final pedido = _actual;
    if (pedido == null || _entregando) return;

    _entregando = true;
    _sinConexion = false;
    _avisar();
    try {
      await _repositorio.marcarEntregado(pedido.id);
      _cancelarGps();
      _actual = null;
      _entregando = false;
      await cargar();
    } on Exception {
      _entregando = false;
      _marcarSinConexion();
    }
  }

  /// Deja de repartir este pedido sin marcarlo entregado.
  Future<void> dejarDeRepartir() async {
    _cancelarGps();
    _actual = null;
    await cargar();
  }

  /// Apaga el GPS y olvida los pedidos. Pasa solo al cerrar la sesión.
  void detener() {
    _cancelarGps();
    _actual = null;
    _pedidos = const [];
    _cambiar(PasoReparto.cargando);
  }

  void _alCambiarSesion(Sesion? sesion) {
    _rol = sesion?.rol;
    if (sesion == null) {
      detener();
    } else if (sesion.rol == Rol.repartidor) {
      unawaited(cargar());
    }
  }

  // Solo si hay alguien del almacén y no está en medio de un reparto.
  void _alRecibirAviso(Aviso aviso) {
    final eligiendo =
        _paso == PasoReparto.eligiendo || _paso == PasoReparto.error;
    if (aviso.tipo == TipoAviso.nuevoPedido && _rol != null && eligiendo) {
      unawaited(cargar());
    }
  }

  Future<void> _alMoverse(Posicion posicion) async {
    final pedido = _actual;
    if (pedido == null) return;

    _posicion = posicion;
    try {
      await _repositorio.enviarPosicion(pedido.id, posicion);
      _sinConexion = false;
    } on Exception {
      _sinConexion = true;
    }
    _avisar();
  }

  void _marcarSinConexion() {
    _sinConexion = true;
    _avisar();
  }

  void _cambiar(PasoReparto paso) {
    _paso = paso;
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  void _cancelarGps() {
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
  }

  @override
  void dispose() {
    _descartado = true;
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    _cancelarGps();
    super.dispose();
  }
}
