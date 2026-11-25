// Persistencia local según la teoría (apunte "Persistencia local"):
// - el carrito, que es una LISTA de objetos, vive en una tabla de SQLite
//   (antes era un JSON en shared_preferences);
// - las preferencias reciben su almacenamiento por constructor y se
//   prueban con InMemorySharedPreferencesAsync.
// Todo corre en la PC, sin emulador: SQLite con sqflite_common_ffi en
// memoria y preferencias en memoria.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/carrito_repository.dart';
import 'package:freshmarket_app/data/services/base_local.dart';
import 'package:freshmarket_app/data/services/carrito_local_service.dart';
import 'package:freshmarket_app/data/services/historial_dao.dart';
import 'package:freshmarket_app/data/services/preferencias.dart';
import 'package:freshmarket_app/domain/models/item_carrito.dart';
import 'package:freshmarket_app/domain/models/producto.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

void main() {
  sqfliteFfiInit();

  group('CarritoDao (SQLite)', () {
    late CarritoDao dao;

    setUp(() {
      dao = CarritoDao(fabrica: databaseFactoryFfi, ruta: inMemoryDatabasePath);
    });

    tearDown(() => dao.cerrar());

    test('cada producto es una fila y vuelven en el mismo orden', () async {
      final repositorio = CarritoRepository(service: dao);
      await repositorio.guardar(const [
        ItemCarrito(producto: queso, cantidad: 1),
        ItemCarrito(producto: yerba, cantidad: 2),
      ]);

      final filas = await dao.leer();
      expect(filas, hasLength(2));
      expect(filas.first['producto_id'], queso.id);

      final items = await repositorio.cargar();
      expect(items.map((item) => item.producto.id), [queso.id, yerba.id]);
      expect(items.last.cantidad, 2);
      expect(items.last.producto.precio, yerba.precio);
    });

    test('guardar reemplaza el carrito entero (en una transacción)', () async {
      final repositorio = CarritoRepository(service: dao);
      await repositorio.guardar(const [
        ItemCarrito(producto: queso),
        ItemCarrito(producto: yerba),
      ]);

      await repositorio.guardar(const [ItemCarrito(producto: leche)]);

      final items = await repositorio.cargar();
      expect(items.single.producto.id, leche.id);
    });

    test('SQLite no tiene bool: "disponible" se guarda como 1 o 0', () async {
      const sinStock = Producto(
        id: 'p-sin',
        nombre: 'Dulce de leche',
        precio: 2500,
        categoria: 'Lácteos',
        disponible: false,
      );
      await CarritoRepository(service: dao)
          .guardar(const [ItemCarrito(producto: sinStock)]);

      final fila = (await dao.leer()).single;
      expect(fila['disponible'], 0);

      final vuelta = ItemCarrito.fromMap(fila);
      expect(vuelta.producto.disponible, isFalse);
    });

    test('un precio sin decimales vuelve como double (as num)', () {
      final item = ItemCarrito.fromMap({
        'producto_id': 'p1',
        'nombre': 'Yerba',
        'precio': 3800, // int, no double
        'categoria': 'Almacén',
        'emoji': '🧉',
        'descripcion': '',
        'disponible': 1,
        'cantidad': 1,
      });

      expect(item.producto.precio, 3800.0);
    });

    test('el carrito sobrevive a "cerrar y volver a abrir" la app', () async {
      final antes = CarritoViewModel(
        repositorio: CarritoRepository(service: dao),
      )
        ..agregarProducto(yerba)
        ..agregarProducto(yerba);
      await antes.guardar();

      // Un ViewModel nuevo sobre la misma base es como volver a abrir.
      final despues = CarritoViewModel(
        repositorio: CarritoRepository(service: dao),
      );
      await despues.restaurar();

      expect(despues.cantidadDe(yerba), 2);
    });
  });

  test('migración 2 -> 3: aparece la tabla carrito y el historial queda',
      () async {
    final carpeta = await Directory.systemTemp.createTemp('freshmarket');
    addTearDown(() => carpeta.delete(recursive: true));
    final ruta = '${carpeta.path}/freshmarket.db';

    // Así era la base en la versión 2: solo la tabla de pedidos.
    final v2 = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (base, _) => HistorialDao.crearTabla(base),
      ),
    );
    await v2.insert(HistorialDao.tabla, {
      'id': 'viejo',
      'numero': 1001,
      'fecha': DateTime(2026, 11).toIso8601String(),
      'metodo_pago': 'debito',
      'total': 7600,
      'items': '[]',
      'direccion': 'San Martín 1234',
    });
    await v2.close();

    // La app nueva abre la misma base: corre onUpgrade, no onCreate.
    final base = BaseLocal(fabrica: databaseFactoryFfi, ruta: ruta);
    addTearDown(base.cerrar);
    final carrito = CarritoDao(base: base);
    final historial = HistorialDao(base: base);

    await CarritoRepository(service: carrito)
        .guardar(const [ItemCarrito(producto: yerba)]);

    expect(await carrito.leer(), hasLength(1));
    expect((await historial.ultimos()).single['id'], 'viejo');
    expect(await (await base.abierta).getVersion(), BaseLocal.version);
  });

  group('Preferencias (inyectadas, en memoria)', () {
    setUp(() {
      // El reemplazo oficial del almacenamiento para pruebas.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('lo guardado se lee después, con la misma clave', () async {
      final preferencias = Preferencias(SharedPreferencesAsync());

      await preferencias.guardar(Preferencias.clavePedidoEnCurso, '{"id":1}');

      // Otra instancia (como volver a abrir la app) ve lo mismo.
      expect(
        await Preferencias().leer(Preferencias.clavePedidoEnCurso),
        '{"id":1}',
      );
    });

    test('olvidarTodo borra solo las claves de la app', () async {
      final almacen = SharedPreferencesAsync();
      await almacen.setString('de_otro_paquete', 'queda');
      final preferencias = Preferencias(almacen);
      await preferencias.guardar(Preferencias.clavePedidoEnCurso, 'algo');

      await preferencias.olvidarTodo();

      expect(await preferencias.leer(Preferencias.clavePedidoEnCurso), isNull);
      expect(await almacen.getString('de_otro_paquete'), 'queda');
    });

    test('en la Web el carrito va en preferencias y vuelve igual', () async {
      final servicio = CarritoLocalServicePreferencias(Preferencias());
      final repositorio = CarritoRepository(service: servicio);

      await repositorio.guardar(const [ItemCarrito(producto: queso, cantidad: 3)]);

      final items = await repositorio.cargar();
      expect(items.single.producto.id, queso.id);
      expect(items.single.cantidad, 3);
    });
  });
}
