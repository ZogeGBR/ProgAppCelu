import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/repositories/pago_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/sesion.dart';

/// Las notificaciones de la app.
///
/// No tiene botones propios: **observa** a otros repositorios (patrón
/// Observer) y decide qué avisos pedir.
/// - Se confirma un pedido → este celular se anota para enterarse cuando
///   sale y cuando llega.
/// - Entra el dueño o el repartidor → se anota para los pedidos nuevos.
/// - Sale → se borra.
///
/// Para la vista solo expone si hay permiso, para mostrar el cartel
/// "Activá las notificaciones" en "Mi pedido".
class AvisosViewModel extends ChangeNotifier {
  AvisosViewModel({
    required NotificacionesRepository repositorio,
    PagoRepository? pagos,
    SesionRepository? sesion,
  }) : _repositorio = repositorio {
    _suscripciones = [
      if (pagos != null) pagos.pedidosConfirmados.listen(_alConfirmarPedido),
      if (sesion != null) sesion.cambios.listen(_alCambiarSesion),
    ];
  }

  final NotificacionesRepository _repositorio;
  late final List<StreamSubscription<Object?>> _suscripciones;
  bool _listo = false;
  bool _descartado = false;

  /// Ya se preguntó el permiso y la persona dijo que no.
  bool get permisoDenegado => _listo && !_repositorio.permisoConcedido;

  /// Se llama al abrir la app, DESPUÉS de crear los ViewModels que
  /// observan los avisos (así ninguno se pierde el primero).
  Future<void> iniciar() async {
    try {
      await _repositorio.iniciar();
    } on Exception catch (error) {
      // Sin notificaciones la app igual funciona.
      debugPrint('No se pudieron preparar las notificaciones: $error');
    }
    _listo = true;
    _avisar();
  }

  Future<void> pedirPermiso() async {
    await _repositorio.pedirPermiso();
    _avisar();
  }

  void _alConfirmarPedido(Pedido pedido) =>
      _sinFrenar(_repositorio.seguirPedido(pedido));

  void _alCambiarSesion(Sesion? sesion) => _sinFrenar(
        sesion == null
            ? _repositorio.olvidarCuenta()
            : _repositorio.anotarCuenta(),
      );

  // Anotarse para los avisos nunca frena ni rompe una compra: si falla
  // (sin conexión), el pedido sigue y solo se pierden los avisos.
  void _sinFrenar(Future<void> tarea) {
    unawaited(
      tarea.catchError((Object error) {
        debugPrint('No se pudo anotar el celular para los avisos: $error');
      }),
    );
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    super.dispose();
  }
}
