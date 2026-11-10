import 'package:flutter/foundation.dart';

import '../models/funciones.dart';

/// Capacidades y políticas de FreshMarket (teoría, unidad 8).
///
/// - **Capacidad**: lo que el dispositivo PUEDE hacer (sacar fotos, tener
///   una base SQLite, programar avisos).
/// - **Política**: lo que la app DEBE hacer con eso (mostrar o no "Cargar
///   con foto", ofrecer efectivo...).
///
/// En vez de repartir `Platform.isAndroid` por toda la app, cada decisión
/// es un getter con **nombre de negocio** acá, en un solo lugar. Se usa
/// `defaultTargetPlatform` y `kIsWeb` de foundation.dart (no `dart:io`, que
/// no existe en Web y rompe el build).
///
/// Se inyecta por constructor como cualquier dependencia: en las pruebas se
/// crea con otra plataforma (`Politicas(plataforma: TargetPlatform.iOS)`) o
/// con `debugDefaultTargetPlatformOverride`.
///
/// Hay tres tipos de chequeo, como en la teoría:
/// 1. **Al compilar**: [muestraCuentasDeDemo] (constante: depende de cómo
///    se compiló la app).
/// 2. **Al ejecutar**: los que dependen del dispositivo ([esCelular],
///    [puedeSacarFotos], [puedeGuardarHistorial]...).
/// 3. **Desde el servidor**: [funciones], que llegan del backend al abrir
///    la app ([permitePagoEnEfectivo], [permiteCargaConFoto]...).
class Politicas {
  Politicas({
    TargetPlatform? plataforma,
    bool? esWeb,
    this.funciones = Funciones.porDefecto,
  })  : plataforma = plataforma ?? defaultTargetPlatform,
        esWeb = esWeb ?? kIsWeb;

  final TargetPlatform plataforma;
  final bool esWeb;
  final Funciones funciones;

  // ---------- 1. Al compilar ----------

  /// Las cuentas de demo solo se muestran si la app se compiló SIN
  /// backend (`--dart-define=URL_BACKEND=...`). Es una constante: el
  /// compilador la resuelve y en la versión real ni siquiera existe el texto.
  static const muestraCuentasDeDemo = !bool.hasEnvironment('URL_BACKEND');

  // ---------- 2. Al ejecutar (según el dispositivo) ----------

  /// Android o iOS, instalada como app (no en el navegador).
  bool get esCelular =>
      !esWeb &&
      (plataforma == TargetPlatform.android ||
          plataforma == TargetPlatform.iOS);

  /// La cámara para cargar productos con una foto: en la computadora o en
  /// el navegador no tiene sentido sacarle una foto a un paquete de yerba.
  bool get puedeSacarFotos => esCelular;

  /// SQLite (sqflite) funciona en Android e iOS; en Web no existe.
  bool get puedeGuardarHistorial => esCelular;

  /// Los avisos programados (zonedSchedule) los muestra el sistema del
  /// celular aunque la app esté cerrada.
  bool get puedeProgramarRecordatorios => esCelular;

  /// En el celular el link de Mercado Pago abre la app de Mercado Pago (si
  /// está instalada); en otro lado, el navegador.
  bool get abreMercadoPagoEnSuApp => esCelular;

  /// El repartidor comparte el GPS solo desde el celular que lleva encima.
  bool get puedeRepartir => esCelular;

  // ---------- 3. Desde el servidor ----------

  bool get permitePagoEnEfectivo => funciones.pagoEnEfectivo;

  /// Hace falta las dos cosas: que el celular tenga cámara Y que el
  /// servidor tenga la IA prendida.
  bool get permiteCargaConFoto => puedeSacarFotos && funciones.cargaConFoto;

  bool get recuerdaCarritoOlvidado =>
      puedeProgramarRecordatorios && funciones.recordatorioCarrito;

  /// Copia con las funciones que mandó el servidor.
  Politicas conFunciones(Funciones nuevas) =>
      Politicas(plataforma: plataforma, esWeb: esWeb, funciones: nuevas);
}
