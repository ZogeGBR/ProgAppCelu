import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/aviso.dart';
import '../../../domain/models/sesion.dart';

/// Las secciones de la barra de abajo, en orden.
enum Seccion { comprar, carrito, miPedido, almacen, repartir }

/// Qué sección de la barra inferior está abierta.
///
/// Observa dos sujetos (patrón Observer):
/// - la sesión: al entrar el dueño abre "Mi almacén", al entrar el
///   repartidor abre "Repartir" y al salir vuelve a "Comprar";
/// - las notificaciones tocadas: abre la sección del aviso.
class NavegacionViewModel extends ChangeNotifier {
  NavegacionViewModel({
    SesionRepository? sesion,
    NotificacionesRepository? notificaciones,
  }) : _rol = sesion?.actual?.rol {
    _suscripciones = [
      if (sesion != null) sesion.cambios.listen(_alCambiarSesion),
      if (notificaciones != null) notificaciones.tocados.listen(_alTocarAviso),
    ];
  }

  late final List<StreamSubscription<Object?>> _suscripciones;
  final _abiertasPorAviso = StreamController<Seccion>.broadcast(sync: true);
  Seccion _actual = Seccion.comprar;
  Rol? _rol;

  Seccion get actual => _actual;

  /// Avisa cuando se abrió una sección por tocar una notificación. La app
  /// lo observa para cerrar las pantallas que haya encima (por ejemplo, la
  /// de pago): si no, la sección cambia "por debajo" y no se ve.
  Stream<Seccion> get abiertasPorAviso => _abiertasPorAviso.stream;

  void irA(Seccion seccion) {
    if (seccion == _actual) return;
    _actual = seccion;
    notifyListeners();
  }

  void _alCambiarSesion(Sesion? sesion) {
    _rol = sesion?.rol;
    irA(_seccionPrincipal());
  }

  void _alTocarAviso(Aviso aviso) {
    final seccion = switch (aviso.tipo) {
      TipoAviso.pedido => Seccion.miPedido,
      // Un pedido nuevo le interesa al almacén. Si en este celular ya no
      // hay nadie del almacén (cerró la sesión), se abre "Comprar".
      TipoAviso.nuevoPedido => _seccionPrincipal(),
    };
    irA(seccion);
    _abiertasPorAviso.add(seccion);
  }

  Seccion _seccionPrincipal() => switch (_rol) {
        Rol.dueno => Seccion.almacen,
        Rol.repartidor => Seccion.repartir,
        null => Seccion.comprar,
      };

  @override
  void dispose() {
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    unawaited(_abiertasPorAviso.close());
    super.dispose();
  }
}
