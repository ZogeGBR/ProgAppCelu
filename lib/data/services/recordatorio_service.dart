import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_datos;
import 'package:timezone/timezone.dart' as tz;

/// Avisos programados para una hora (segundo plano, teoría unidad 12).
///
/// Con `zonedSchedule` se le pide al SISTEMA: "a tal hora, mostrá este
/// aviso". No corre código Dart a esa hora: lo muestra Android/iOS aunque
/// la app esté cerrada.
abstract interface class RecordatorioService {
  /// Mismo [id] = reemplaza al anterior (no se duplica).
  Future<void> programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime cuando,
  });

  Future<void> cancelar(int id);
}

class RecordatorioServicePlugin implements RecordatorioService {
  RecordatorioServicePlugin({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// El almacén está en Mendoza: los avisos van con esa hora, aunque el
  /// celular esté configurado en otra zona.
  static const zonaHoraria = 'America/Argentina/Buenos_Aires';

  static const _canal = AndroidNotificationDetails(
    'recordatorios',
    'Recordatorios',
    channelDescription: 'Por ejemplo, si dejaste productos en el carrito.',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  static bool _zonasCargadas = false;

  static void _cargarZonasHorarias() {
    if (_zonasCargadas) return;
    tz_datos.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(zonaHoraria));
    _zonasCargadas = true;
  }

  @override
  Future<void> programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime cuando,
  }) async {
    _cargarZonasHorarias();
    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: cuerpo,
      // TZDateTime (no DateTime): la hora con su zona horaria.
      scheduledDate: tz.TZDateTime.from(cuando, tz.local),
      notificationDetails: const NotificationDetails(
        android: _canal,
        iOS: DarwinNotificationDetails(),
      ),
      // Aproximado: funciona aunque el celular esté en reposo (Doze) y no
      // necesita el permiso especial de alarmas exactas.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelar(int id) => _plugin.cancel(id: id);
}

/// Para la demo en la computadora y las pruebas: anota lo que programaría.
class RecordatorioServiceSimulado implements RecordatorioService {
  final programados = <int, DateTime>{};

  @override
  Future<void> programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime cuando,
  }) async {
    programados[id] = cuando;
  }

  @override
  Future<void> cancelar(int id) async {
    programados.remove(id);
  }
}
