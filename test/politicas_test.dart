// Capacidades y políticas: las decisiones según la plataforma y el
// servidor están en UN lugar y se prueban sin tener otro celular.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/funciones_repository.dart';
import 'package:freshmarket_app/data/services/funciones_service.dart';
import 'package:freshmarket_app/domain/models/funciones.dart';
import 'package:freshmarket_app/domain/politicas/politicas.dart';

/// Un servidor que nunca contesta (para probar el timeout). Un Completer
/// que nadie completa: no deja ningún Timer colgado al terminar.
class _ServidorColgado implements FuncionesService {
  @override
  Future<Map<String, dynamic>> obtener() =>
      Completer<Map<String, dynamic>>().future;
}

class _ServidorCaido implements FuncionesService {
  @override
  Future<Map<String, dynamic>> obtener() async => throw Exception('caído');
}

void main() {
  group('al ejecutar (según el dispositivo)', () {
    test('en Android e iOS todo está disponible', () {
      for (final plataforma in [TargetPlatform.android, TargetPlatform.iOS]) {
        final politicas = Politicas(plataforma: plataforma, esWeb: false);
        expect(politicas.esCelular, isTrue);
        expect(politicas.puedeSacarFotos, isTrue);
        expect(politicas.puedeGuardarHistorial, isTrue);
        expect(politicas.puedeProgramarRecordatorios, isTrue);
      }
    });

    test('en el navegador no hay cámara, SQLite ni avisos programados', () {
      final politicas = Politicas(
        plataforma: TargetPlatform.android,
        esWeb: true,
      );
      expect(politicas.esCelular, isFalse);
      expect(politicas.permiteCargaConFoto, isFalse);
      expect(politicas.puedeGuardarHistorial, isFalse);
      expect(politicas.recuerdaCarritoOlvidado, isFalse);
    });

    test('en una computadora con Windows tampoco es un celular', () {
      final politicas = Politicas(
        plataforma: TargetPlatform.windows,
        esWeb: false,
      );
      expect(politicas.puedeRepartir, isFalse);
      expect(politicas.abreMercadoPagoEnSuApp, isFalse);
    });

    test('sin parámetros usa la plataforma real (simulada con el override)',
        () {
      // Es global: hay que dejarla como estaba al terminar.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(Politicas().esCelular, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(Politicas().esCelular, isTrue);
    });
  });

  group('desde el servidor', () {
    test('el servidor puede apagar el efectivo y la carga con foto', () {
      final politicas = Politicas(
        plataforma: TargetPlatform.android,
        esWeb: false,
      ).conFunciones(
        const Funciones(pagoEnEfectivo: false, cargaConFoto: false),
      );
      expect(politicas.permitePagoEnEfectivo, isFalse);
      expect(politicas.permiteCargaConFoto, isFalse);
      // La plataforma se conserva al copiar.
      expect(politicas.esCelular, isTrue);
    });

    test('lee lo que manda el servidor; lo que falta queda prendido',
        () async {
      final repositorio = FuncionesRepository(
        service: const FuncionesServiceSimulado({'pagoEnEfectivo': false}),
      );
      final funciones = await repositorio.cargar();
      expect(funciones.pagoEnEfectivo, isFalse);
      expect(funciones.cargaConFoto, isTrue);
    });

    test('si el servidor no contesta a tiempo, sigue con todo prendido',
        () async {
      final repositorio = FuncionesRepository(
        service: _ServidorColgado(),
        limite: const Duration(milliseconds: 20),
      );
      final funciones = await repositorio.cargar();
      expect(funciones.pagoEnEfectivo, isTrue);
    });

    test('si el servidor falla, sigue con todo prendido', () async {
      final repositorio = FuncionesRepository(service: _ServidorCaido());
      expect((await repositorio.cargar()).cargaConFoto, isTrue);
    });
  });

  test('al compilar: las cuentas de demo solo existen sin URL_BACKEND', () {
    // Las pruebas se corren sin --dart-define: es la demo.
    expect(Politicas.muestraCuentasDeDemo, isTrue);
  });
}
