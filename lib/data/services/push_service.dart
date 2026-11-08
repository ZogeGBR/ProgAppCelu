import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/models/aviso.dart';

/// De dónde llegan las notificaciones push (patrón Strategy).
///
/// - [PushServiceFirebase]: Firebase Cloud Messaging, con el backend real.
/// - [PushServiceSimulado]: para la demo sin backend; el "servidor"
///   simulado manda los avisos con [PushServiceSimulado.enviar].
abstract interface class PushService {
  /// El token que identifica a ESTE celular en Firebase. El backend lo usa
  /// para mandarle avisos. null: este celular no puede recibir push.
  Future<String?> obtenerToken();

  /// Avisos que llegan con la app abierta. Android NO los muestra solo
  /// (con la app en primer plano), así que la app los muestra con una
  /// notificación local.
  Stream<Aviso> get recibidos;

  /// La persona tocó una notificación push con la app en segundo plano o
  /// cerrada.
  Stream<Aviso> get tocados;
}

/// Firebase Cloud Messaging.
///
/// Con la app cerrada o en segundo plano, Android muestra la notificación
/// sola (el backend manda `notification` con título y texto): no hace
/// falta código que corra en segundo plano.
class PushServiceFirebase implements PushService {
  PushServiceFirebase({FirebaseMessaging? mensajeria})
      : _mensajeria = mensajeria ?? FirebaseMessaging.instance;

  final FirebaseMessaging _mensajeria;

  @override
  Future<String?> obtenerToken() async {
    try {
      // getToken() quedó marcado como viejo en firebase_messaging 17 (lo
      // reemplaza register() + onRegistered, que devuelve otro tipo de id).
      // Se usa a propósito: el backend manda con firebase-admin, que
      // documenta este token de registro. Revisar al actualizar el paquete.
      // ignore: deprecated_member_use
      return await _mensajeria.getToken();
    } on Exception {
      // Sin Google Play Services o sin conexión: la app sigue sin push.
      return null;
    }
  }

  @override
  Stream<Aviso> get recibidos => FirebaseMessaging.onMessage.map(_aAviso);

  @override
  Stream<Aviso> get tocados async* {
    // Si la app estaba CERRADA y se abrió por tocar el aviso, ese aviso
    // se pide una vez al arrancar.
    final inicial = await _mensajeria.getInitialMessage();
    if (inicial != null) yield _aAviso(inicial);
    // Si estaba en segundo plano, llega por este stream.
    yield* FirebaseMessaging.onMessageOpenedApp.map(_aAviso);
  }

  // Adapter: convierte el mensaje de Firebase en el modelo de la app.
  Aviso _aAviso(RemoteMessage mensaje) => Aviso.desdeDatos(
        mensaje.data,
        titulo: mensaje.notification?.title,
        cuerpo: mensaje.notification?.body,
      );
}

/// Push de mentira para la demo: hace de Firebase y de backend a la vez.
///
/// [token]: el de la demo. Con backend real pero sin Firebase se crea con
/// `token: null`, para no anotar en la base un celular que no puede
/// recibir nada.
class PushServiceSimulado implements PushService {
  PushServiceSimulado({this.token = tokenDemo});

  static const tokenDemo = 'token-demo-de-este-celular';

  final String? token;
  final _recibidos = StreamController<Aviso>.broadcast();

  /// Lo llama el servidor simulado (ver SeguimientoServiceSimulado).
  void enviar(Aviso aviso) => _recibidos.add(aviso);

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Stream<Aviso> get recibidos => _recibidos.stream;

  // En la demo todo pasa con la app abierta: se toca la notificación
  // local, que llega por NotificacionLocalService.tocadas.
  @override
  Stream<Aviso> get tocados => const Stream.empty();
}
