// El DAO de SQLite contra una base de verdad, en memoria
// (sqflite_common_ffi), como indica la teoría para probar sqflite.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/historial_repository.dart';
import 'package:freshmarket_app/data/services/historial_dao.dart';
import 'package:freshmarket_app/domain/models/item_carrito.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/domain/models/pedido.dart';
import 'package:freshmarket_app/domain/models/pedido_anterior.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

Pedido _pedido(String id, DateTime fecha, {int numero = 1001}) => Pedido(
      id: id,
      numero: numero,
      items: const [ItemCarrito(producto: yerba, cantidad: 2)],
      metodoPago: MetodoPago.debito,
      fecha: fecha,
      direccion: 'San Martín 1234',
    );

void main() {
  sqfliteFfiInit();

  late HistorialDao dao;

  setUp(() {
    dao = HistorialDao(fabrica: databaseFactoryFfi, ruta: inMemoryDatabasePath);
  });

  tearDown(() => dao.cerrar());

  test('toMap y fromMap ida y vuelta', () {
    final original = PedidoAnterior.desdePedido(_pedido('a', DateTime(2026)));
    final copia = PedidoAnterior.fromMap(original.toMap());

    expect(copia.id, 'a');
    expect(copia.total, 7600);
    expect(copia.items.single.producto.nombre, 'Yerba mate 1kg');
    expect(copia.direccion, 'San Martín 1234');
  });

  test('guarda y devuelve los más nuevos primero', () async {
    final repositorio = HistorialRepository(service: dao);
    await repositorio.guardar(_pedido('viejo', DateTime(2026, 10, 1)));
    await repositorio.guardar(_pedido('nuevo', DateTime(2026, 11, 1)));

    final pedidos = await repositorio.ultimos();
    expect(pedidos.map((p) => p.id).toList(), ['nuevo', 'viejo']);
  });

  test('el mismo pedido dos veces no se duplica', () async {
    final repositorio = HistorialRepository(service: dao);
    final pedido = _pedido('a', DateTime(2026, 11, 1));
    await repositorio.guardar(pedido);
    await repositorio.guardar(pedido);

    expect(await repositorio.ultimos(), hasLength(1));
  });

  test('borra solo lo de más de 90 días', () async {
    final hoy = DateTime(2026, 11, 10);
    final repositorio = HistorialRepository(service: dao, reloj: () => hoy);
    await repositorio.guardar(_pedido('reciente', DateTime(2026, 11, 1)));
    await repositorio.guardar(_pedido('viejo', DateTime(2026, 6, 1)));

    expect(await repositorio.limpiarViejos(), 1);
    expect((await repositorio.ultimos()).single.id, 'reciente');
  });

  test('migración: una base de la versión 1 pasa a la 2 sin perder datos',
      () async {
    final carpeta = await Directory.systemTemp.createTemp('freshmarket');
    addTearDown(() => carpeta.delete(recursive: true));
    final ruta = '${carpeta.path}/historial.db';

    // Así era la tabla en la versión 1 (sin dirección).
    final v1 = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (base, _) => base.execute('''
          CREATE TABLE pedidos (
            id TEXT PRIMARY KEY, numero INTEGER NOT NULL, fecha TEXT NOT NULL,
            metodo_pago TEXT NOT NULL, total REAL NOT NULL, items TEXT NOT NULL
          )
        '''),
      ),
    );
    final viejo = PedidoAnterior.desdePedido(_pedido('v1', DateTime(2026)))
        .toMap()
      ..remove('direccion');
    await v1.insert('pedidos', viejo);
    await v1.close();

    // La app nueva abre la misma base: corre onUpgrade, no onCreate.
    final actualizado = HistorialDao(fabrica: databaseFactoryFfi, ruta: ruta);
    final filas = await actualizado.ultimos();
    expect(filas.single['id'], 'v1');
    expect(filas.single['direccion'], '');
    await actualizado.cerrar();
  });
}
