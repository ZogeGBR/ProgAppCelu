import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/models/aviso.dart';
import 'preferencias.dart';

/// Push que llega con la app en SEGUNDO PLANO o CERRADA (el cuarto caso
/// de FCM, además de onMessage, onMessageOpenedApp y getInitialMessage).
///
/// Reglas de la teoría que se cumplen acá:
/// - Es una función de NIVEL SUPERIOR (no un método) con
///   `@pragma('vm:entry-point')`: si no, el compilador la borra en release
///   porque nadie la llama desde Dart.
/// - Corre en OTRO isolate, que no ve nada de la app (ni ViewModels ni
///   variables): por eso inicializa Firebase de nuevo y deja el dato en
///   almacenamiento compartido (shared_preferences).
/// - Tiene poco tiempo (~30 s): solo guarda, no hace pedidos largos.
///
/// La notificación en la barra la muestra Android solo; esto anota qué
/// llegó y cuándo, para que la app lo sepa la próxima vez que se abra.
@pragma('vm:entry-point')
Future<void> manejarPushEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp();
  await const Preferencias().guardar(
    Preferencias.claveUltimoAvisoEnSegundoPlano,
    jsonEncode({
      ...mensaje.data,
      'titulo': mensaje.notification?.title,
      'recibidoEn': DateTime.now().toIso8601String(),
    }),
  );
}

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
