// Datos reales en la demo: la calle del punto del mapa (Nominatim), el
// camino de la bici por las calles (OSRM) y la lectura de la foto del
// producto. Todo se prueba sin internet: los servidores se reemplazan por
// respuestas armadas a mano (MockClient).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/services/api_client.dart';
import 'package:freshmarket_app/data/services/geocodificacion_service.dart';
import 'package:freshmarket_app/data/services/lector_de_etiqueta.dart';
import 'package:freshmarket_app/data/services/ruta_service.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
import 'package:freshmarket_app/domain/models/almacen.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/domain/models/recorrido.dart';
import 'package:freshmarket_app/domain/models/seguimiento_pedido.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object datos, [int codigo = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), codigo);

void main() {
  // Un camino en "L": 2 cuadras al este y después 2 al norte.
  const esquina = Posicion(latitud: -32.8870, longitud: -68.8440);
  const casa = Posicion(latitud: -32.8830, longitud: -68.8440);
  final enL = Recorrido([Almacen.ubicacion, esquina, casa]);

  group('Recorrido', () {
    test('mide el camino sumando los tramos', () {
      final primerTramo = Recorrido.distanciaMetros(Almacen.ubicacion, esquina);
      final segundoTramo = Recorrido.distanciaMetros(esquina, casa);

      expect(enL.largoMetros, closeTo(primerTramo + segundoTramo, 0.01));
      expect(segundoTramo, closeTo(445, 5)); // 0,004° de latitud ≈ 445 m
    });

    test('la bici dobla en la esquina: no corta en diagonal', () {
      final primerTramo = Recorrido.distanciaMetros(Almacen.ubicacion, esquina);

      final enLaEsquina = enL.puntoA(primerTramo);
      expect(enLaEsquina.latitud, closeTo(esquina.latitud, 1e-9));
      expect(enLaEsquina.longitud, closeTo(esquina.longitud, 1e-9));

      // Pasada la esquina, va por la calle de la casa (misma longitud).
      final despues = enL.puntoA(primerTramo + 100);
      expect(despues.longitud, closeTo(esquina.longitud, 1e-9));
    });

    test('empieza en el almacén y termina en la casa', () {
      expect(enL.puntoEnFraccion(0), Almacen.ubicacion);
      expect(enL.puntoEnFraccion(1), casa);
      expect(enL.puntoEnFraccion(2), casa);
    });

    test('sabe cuánto del camino ya hizo la bici', () {
      final mitad = enL.puntoEnFraccion(0.5);

      expect(enL.metrosHasta(mitad), closeTo(enL.largoMetros / 2, 1));
    });

    test('el almacén de Don Ceferino está en Gutiérrez 746', () {
      expect(Almacen.direccion, contains('Gutiérrez 746'));
      expect(Almacen.ubicacion.latitud, closeTo(-32.887, 0.001));
      expect(Almacen.ubicacion.longitud, closeTo(-68.848, 0.001));
    });
  });

  group('RutaServiceOsrm', () {
    final respuestaOsrm = {
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-68.84838, -32.88693],
              [-68.8440, -32.8870],
              [-68.8440, -32.8830],
            ],
          },
        },
      ],
    };

    test('lee los puntos de la calle (OSRM los manda como lng,lat)', () async {
      final pedidos = <Uri>[];
      final service = RutaServiceOsrm(
        cliente: MockClient((pedido) async {
          pedidos.add(pedido.url);
          return _json(respuestaOsrm);
        }),
      );

      final ruta = await service.rutaEntre(Almacen.ubicacion, casa);

      expect(ruta.puntos.first, Almacen.ubicacion);
      expect(ruta.puntos.last, casa);
      expect(ruta.puntos, contains(esquina));
      expect(pedidos.single.host, 'routing.openstreetmap.de');
      expect(pedidos.single.path, contains('-68.848384,-32.886929;'));
    });

    test('si el primer servidor falla, prueba el segundo', () async {
      final hosts = <String>[];
      final service = RutaServiceOsrm(
        cliente: MockClient((pedido) async {
          hosts.add(pedido.url.host);
          return pedido.url.host == 'routing.openstreetmap.de'
              ? http.Response('caído', 503)
              : _json(respuestaOsrm);
        }),
      );

      final ruta = await service.rutaEntre(Almacen.ubicacion, casa);

      expect(hosts, ['routing.openstreetmap.de', 'router.project-osrm.org']);
      expect(ruta.esValido, isTrue);
    });

    test('sin ruta posible, avisa con un error', () async {
      final service = RutaServiceOsrm(
        cliente: MockClient((_) async => _json({'code': 'NoRoute'})),
      );

      await expectLater(
        service.rutaEntre(Almacen.ubicacion, casa),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SeguimientoServiceSimulado con ruta', () {
    test('la bici sale del almacén y sigue el camino hasta la casa', () async {
      final service = SeguimientoServiceSimulado(
        intervalo: const Duration(milliseconds: 1),
        pasosEnCamino: 5,
        rutas: _RutaFija(enL),
      );

      final novedades = await service
          .seguirPedido('p-1', destino: casa.toJson())
          .map(SeguimientoPedido.fromJson)
          .toList();
      final enCamino = novedades.where((n) => n.posicionRepartidor != null);

      expect(enCamino.first.posicionRepartidor, Almacen.ubicacion);
      expect(enCamino.last.posicionRepartidor, casa);
      expect(enCamino.first.ruta, enL.puntos);
      // Cada posición está sobre el camino (a menos de 1 metro).
      for (final novedad in enCamino) {
        final posicion = novedad.posicionRepartidor!;
        final sobreElCamino = enL.puntoA(enL.metrosHasta(posicion));
        expect(
          Recorrido.distanciaMetros(posicion, sobreElCamino),
          lessThan(1),
        );
      }
    });

    test('sin internet para la ruta, va en línea recta igual', () async {
      final service = SeguimientoServiceSimulado(
        intervalo: const Duration(milliseconds: 1),
        pasosEnCamino: 3,
        rutas: _RutaQueFalla(),
      );

      final novedades = await service
          .seguirPedido('p-1', destino: casa.toJson())
          .map(SeguimientoPedido.fromJson)
          .toList();

      expect(novedades.last.ruta, [Almacen.ubicacion, casa]);
      expect(novedades.where((n) => n.posicionRepartidor != null), isNotEmpty);
    });
  });

  group('GeocodificacionServiceNominatim', () {
    test('devuelve la calle REAL del punto tocado', () async {
      late Uri consultada;
      final service = GeocodificacionServiceNominatim(
        cliente: MockClient((pedido) async {
          consultada = pedido.url;
          expect(pedido.headers['User-Agent'], contains('FreshMarket'));
          return _json({
            'address': {
              'road': 'Avenida San Martín',
              'house_number': '1250',
              'suburb': 'Ciudad',
              'city': 'Mendoza',
            },
          });
        }),
      );

      final datos = await service.direccionDe(-32.889, -68.845);

      expect(datos['direccion'], 'Avenida San Martín 1250, Ciudad');
      expect(consultada.host, 'nominatim.openstreetmap.org');
      expect(consultada.queryParameters['lat'], '-32.889');
    });

    test('dos puntos distintos dan dos calles distintas', () async {
      final service = GeocodificacionServiceNominatim(
        cliente: MockClient((pedido) async {
          final lat = pedido.url.queryParameters['lat'];
          return _json({
            'address': {
              'road': lat == '-32.889' ? 'Gutiérrez' : 'Belgrano',
              'city': 'Mendoza',
            },
          });
        }),
      );

      final una = await service.direccionDe(-32.889, -68.845);
      final otra = await service.direccionDe(-32.881, -68.851);

      expect(una['direccion'], 'Gutiérrez, Mendoza');
      expect(otra['direccion'], 'Belgrano, Mendoza');
    });

    test('si Nominatim falla tira un error (no inventa una calle)', () async {
      final service = GeocodificacionServiceNominatim(
        cliente: MockClient((_) async => http.Response('', 503)),
      );

      await expectLater(
        service.direccionDe(-32.889, -68.845),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('LectorDeEtiqueta', () {
    test('arma el nombre con lo más grande del envase y la cantidad', () {
      final ficha = LectorDeEtiqueta.armar(
        lineas: const [
          LineaLeida(texto: 'NATURA', alto: 60, arriba: 40),
          LineaLeida(texto: 'ACEITE DE GIRASOL', alto: 40, arriba: 100),
          LineaLeida(texto: '1,5 L', alto: 20, arriba: 200),
          LineaLeida(texto: 'Industria Argentina', alto: 8, arriba: 300),
          LineaLeida(texto: 'Valor energético 120 kcal', alto: 6, arriba: 320),
        ],
        etiquetas: const ['Bottle'],
      );

      expect(ficha['nombre'], 'Natura Aceite de Girasol 1,5 L');
      expect(ficha['categoria'], 'Almacén');
      expect(ficha['emoji'], '🫒');
      expect(ficha.containsKey('precioSugerido'), isFalse);
    });

    test('la letra chica no cambia la categoría', () {
      final ficha = LectorDeEtiqueta.armar(
        lineas: const [
          LineaLeida(texto: 'Galletitas Dulces', alto: 50, arriba: 10),
          LineaLeida(
            texto: 'Ingredientes: harina, azúcar, leche',
            alto: 5,
            arriba: 300,
          ),
        ],
      );

      expect(ficha['nombre'], 'Galletitas Dulces');
      expect(ficha['categoria'], 'Panadería');
    });

    test('sin texto, usa lo que se ve en la foto', () {
      final ficha = LectorDeEtiqueta.armar(
        lineas: const [],
        etiquetas: const ['Banana', 'Fruit'],
      );

      expect(ficha['nombre'], 'Banana');
      expect(ficha['categoria'], 'Verdulería');
      expect(ficha['emoji'], '🍌');
    });

    test('si no reconoce nada, no inventa: el dueño escribe el nombre', () {
      final ficha = LectorDeEtiqueta.armar(lineas: const []);

      expect(ficha['nombre'], '');
      expect(ficha['categoria'], 'Otros');
    });
  });
}

class _RutaFija implements RutaService {
  _RutaFija(this.recorrido);

  final Recorrido recorrido;

  @override
  Future<Recorrido> rutaEntre(Posicion desde, Posicion hasta) async =>
      recorrido;
}

class _RutaQueFalla implements RutaService {
  @override
  Future<Recorrido> rutaEntre(Posicion desde, Posicion hasta) async =>
      throw Exception('sin internet');
}
