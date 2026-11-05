// Pruebas de caracterización (paso 0 del plan de refactoring).
//
// Se escribieron contra la V2, ANTES de reorganizar el proyecto en
// capas, y siguen fijando el mismo comportamiento observable: numeración
// de pedidos, totales, copia de los ítems y formato de precios.
//
// Único cambio a propósito: antes confirmarPedido() armaba el pedido y
// vaciaba el carrito en un solo paso. Ahora son dos (armarPedido y
// vaciarCarrito), porque el carrito se vacía recién cuando Mercado Pago
// aprueba el pago. Las expectativas son las mismas.
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/core/formato.dart';

import 'fakes.dart';

void main() {
  test('el primer pedido es el #1001 y los siguientes suman de a uno', () {
    final carrito = CarritoViewModel()..agregarProducto(yerba);
    final primero = carrito.armarPedido(MetodoPago.debito);
    carrito
      ..vaciarCarrito()
      ..agregarProducto(queso);
    final segundo = carrito.armarPedido(MetodoPago.debito);

    expect(primero.numero, 1001);
    expect(segundo.numero, 1002);
  });

  test('el total es la suma de precio por cantidad de cada ítem', () {
    final carrito = CarritoViewModel()
      ..agregarProducto(yerba)
      ..agregarProducto(yerba)
      ..agregarProducto(yerba)
      ..agregarProducto(queso);

    expect(carrito.total, 3800 * 3 + 6500);
    expect(carrito.cantidadTotal, 4);
  });

  test('el pedido conserva los ítems aunque el carrito se vacíe', () {
    final carrito = CarritoViewModel()..agregarProducto(queso);
    final pedido = carrito.armarPedido(MetodoPago.billeteraMercadoPago);
    carrito.vaciarCarrito();

    expect(carrito.estaVacio, isTrue);
    expect(pedido.items.single.producto.id, 'p6');
    expect(pedido.total, 6500);
  });

  test('formatearPrecio redondea al peso más cercano', () {
    expect(formatearPrecio(1499.6), '\$1.500');
    expect(formatearPrecio(999.4), '\$999');
  });
}
