import 'dart:async';

import '../../domain/models/aviso.dart';
import '../../domain/models/pedido.dart';
import '../services/avisos_service.dart';
import '../services/notificacion_local_service.dart';
import '../services/push_service.dart';

/// Une las tres piezas de las notificaciones y es la única que las conoce:
///
/// - [PushService]: de dónde llegan los avisos (Firebase o simulado).
/// - [NotificacionLocalService]: cómo se muestran en el celular.
/// - [AvisosService]: qué avisos le pide este celular al backend.
///
/// Patrón Observer: es el **sujeto** de los avisos. Publica en [recibidos]
/// cada aviso que llega con la app abierta y en [tocados] cada vez que la
/// persona toca una notificación. La barra de abajo y el reparto observan
/// esos streams; no saben si el aviso vino de Firebase o de la demo.
class NotificacionesRepository {
  NotificacionesRepository({
    required PushService push,
    required NotificacionLocalService local,
    required AvisosService servidor,
  })  : _push = push,
        _local = local,
        _servidor = servidor;

  final PushService _push;
  final NotificacionLocalService _local;
  final AvisosService _servidor;

  final _recibidos = StreamController<Aviso>.broadcast(sync: true);
  final _tocados = StreamController<Aviso>.broadcast(sync: true);
  final _suscripciones = <StreamSubscription<Aviso>>[];
  String? _token;
  bool _permiso = false;
  bool _iniciado = false;

  Stream<Aviso> get recibidos => _recibidos.stream;
  Stream<Aviso> get tocados => _tocados.stream;

  /// Si la persona dejó mostrar notificaciones.
  bool get permisoConcedido => _permiso;

  /// Prepara el canal, pide el permiso y empieza a escuchar los avisos.
  /// Se llama una vez al abrir la app. Si algo falla (por ejemplo, un
  /// celular sin Google Play), la app sigue andando sin notificaciones.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _suscripciones
      ..add(_push.recibidos.listen(_alRecibir))
      ..add(_push.tocados.listen(_tocados.add))
      ..add(_local.tocadas.listen(_tocados.add));
    await _local.iniciar();
    _permiso = await _local.pedirPermiso();
  }

  /// Vuelve a pedir el permiso (desde el cartel de "Mi pedido").
  Future<bool> pedirPermiso() async {
    _permiso = await _local.pedirPermiso();
    return _permiso;
  }

  /// El cliente quiere enterarse cuando su pedido sale y cuando llega.
  Future<void> seguirPedido(Pedido pedido) async {
    final token = await _tokenDelCelular();
    if (token != null) await _servidor.anotarParaPedido(pedido.id, token);
  }

  /// Entró el dueño o el repartidor: avisos de pedidos nuevos.
  Future<void> anotarCuenta() async {
    final token = await _tokenDelCelular();
    if (token != null) await _servidor.anotarCuenta(token);
  }

  /// Salió: este celular deja de recibir los avisos del almacén.
  Future<void> olvidarCuenta() async {
    final token = await _tokenDelCelular();
    if (token != null) await _servidor.olvidarCuenta(token);
  }

  // Con la app abierta Android no muestra el push: se muestra acá, para
  // que la persona lo vea igual que con la app cerrada.
  Future<void> _alRecibir(Aviso aviso) async {
    _recibidos.add(aviso);
    try {
      await _local.mostrar(aviso);
    } on Exception {
      // Si no se pudo mostrar, el aviso igual llegó a quien lo observa.
    }
  }

  // El token se guarda la primera vez que se consigue (es una consulta a
  // Google). Si no se pudo (sin internet), se vuelve a intentar la próxima.
  Future<String?> _tokenDelCelular() async =>
      _token ??= await _push.obtenerToken();

  void dispose() {
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    unawaited(_recibidos.close());
    unawaited(_tocados.close());
  }
}
