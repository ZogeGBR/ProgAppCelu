// Pruebas de caracterización (paso 0 del plan de refactoring).
//
// Fijan el comportamiento OBSERVABLE de la versión V2 antes de
// reorganizar el proyecto en capas. Solo miran lo que se ve desde
// afuera (totales, formato, numeración de pedidos), nunca detalles
// internos, para no frenar el refactoring.
import 'package:flutter_test/flutter_test.dart';

import 'package:freshmarket_app/models/metodo_pago.dart';
import 'package:freshmarket_app/models/producto.dart';
import 'package:freshmarket_app/providers/carrito_provider.dart';
import 'package:freshmarket_app/utils/formato.dart';

void main() {
  final fideos = catalogoFreshMarket.firstWhere((p) => p.id == 'p1'); // 1200
  final queso = catalogoFreshMarket.firstWhere((p) => p.id == 'p6'); // 6500

  test('el primer pedido es el #1001 y los siguientes suman de a uno', () {
    final carrito = CarritoProvider()..agregarProducto(fideos);
    final primero = carrito.confirmarPedido(MetodoPago.tarjeta);
    carrito.agregarProducto(queso);
    final segundo = carrito.confirmarPedido(MetodoPago.tarjeta);

    expect(primero.numero, 1001);
    expect(segundo.numero, 1002);
  });

  test('el total es la suma de precio por cantidad de cada ítem', () {
    final carrito = CarritoProvider()
      ..agregarProducto(fideos)
      ..agregarProducto(fideos)
      ..agregarProducto(fideos)
      ..agregarProducto(queso);

    expect(carrito.total, 1200 * 3 + 6500);
    expect(carrito.cantidadTotal, 4);
  });

  test('el pedido conserva los ítems aunque el carrito se vacíe', () {
    final carrito = CarritoProvider()..agregarProducto(queso);
    final pedido = carrito.confirmarPedido(MetodoPago.mercadoPago);

    expect(carrito.estaVacio, isTrue);
    expect(pedido.items.single.producto.id, 'p6');
    expect(pedido.total, 6500);
  });

  test('formatearPrecio redondea al peso más cercano', () {
    expect(formatearPrecio(1499.6), '\$1.500');
    expect(formatearPrecio(999.4), '\$999');
  });
}
