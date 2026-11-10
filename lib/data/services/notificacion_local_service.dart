import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/aviso.dart';

/// Muestra notificaciones en la barra del celular desde la propia app.
///
/// Hace falta aunque haya Firebase: con la app ABIERTA, Android no muestra
/// el push solo; la app lo recibe y lo muestra con este servicio.
abstract interface class NotificacionLocalService {
  /// Crea el canal de Android "Pedidos". Se llama una vez al arrancar.
  Future<void> iniciar();

  /// Android 13 o más pide permiso para mostrar notificaciones. Devuelve
  /// si quedó concedido.
  Future<bool> pedirPermiso();

  Future<void> mostrar(Aviso aviso);

  /// La persona tocó una notificación que mostró la app.
  Stream<Aviso> get tocadas;
}

/// Implementación con el paquete flutter_local_notifications.
class NotificacionLocalServicePlugin implements NotificacionLocalService {
  NotificacionLocalServicePlugin({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Mismo id que usa el backend (push.js, CANAL_ANDROID): así los push de
  /// Firebase y las notificaciones locales caen en el mismo canal y la
  /// persona los puede silenciar juntos desde Ajustes.
  static const canal = AndroidNotificationChannel(
    'pedidos',
    'Pedidos',
    description: 'Cuando tu pedido sale, cuando llega y los pedidos nuevos.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final _tocadas = StreamController<Aviso>.broadcast();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> iniciar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        // El ícono de la app, en blanco sobre la barra de estado.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // En iOS el permiso se pide aparte, con pedirPermiso().
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) =>
          _alTocar(respuesta.payload),
    );
    await _android?.createNotificationChannel(canal);

    // Si la app estaba cerrada y se abrió tocando una notificación local.
    final inicio = await _plugin.getNotificationAppLaunchDetails();
    if (inicio?.didNotificationLaunchApp ?? false) {
      _alTocar(inicio?.notificationResponse?.payload);
    }
  }

  @override
  Future<bool> pedirPermiso() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> mostrar(Aviso aviso) {
    return _plugin.show(
      id: aviso.idNotificacion,
      title: aviso.titulo,
      body: aviso.cuerpo,
      payload: aviso.aTexto(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Stream<Aviso> get tocadas => _tocadas.stream;

  void _alTocar(String? payload) {
    final aviso = Aviso.desdeTexto(payload);
    if (aviso != null) _tocadas.add(aviso);
  }
}
