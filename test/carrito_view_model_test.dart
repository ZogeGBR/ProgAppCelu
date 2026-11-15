import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/core/formato.dart';

import 'fakes.dart';

void main() {
  group('CarritoViewModel', () {
    late CarritoViewModel carrito;

    setUp(() => carrito = CarritoViewModel());

    test('agregar el mismo producto suma cantidad en vez de duplicarlo', () {
      carrito
        ..agregarProducto(yerba)
        ..agregarProducto(yerba)
        ..agregarProducto(leche);

      expect(carrito.items.length, 2);
      expect(carrito.cantidadDe(yerba), 2);
      expect(carrito.cantidadTotal, 3);
      expect(carrito.total, 3800 * 2 + 1500);
    });

    test('quitar hasta 0 saca el producto del carrito', () {
      carrito
        ..agregarProducto(leche)
        ..quitarProducto(leche);

      expect(carrito.estaVacio, isTrue);
    });

    test('eliminarProducto saca el ítem entero', () {
      carrito
        ..agregarProducto(yerba)
        ..agregarProducto(yerba)
        ..eliminarProducto(yerba);

      expect(carrito.cantidadDe(yerba), 0);
    });

    test('armarPedido NO vacía el carrito (se vacía al aprobar el pago)', () {
      carrito
        ..agregarProducto(yerba)
        ..agregarProducto(leche);

      final pedido = carrito.armarPedido(MetodoPago.credito);

      expect(carrito.estaVacio, isFalse);
      expect(pedido.total, 5300);
      expect(pedido.cantidadProductos, 2);
      expect(pedido.metodoPago, MetodoPago.credito);
    });

    test('cambiar el carrito después no cambia un pedido ya armado', () {
      carrito.agregarProducto(yerba);
      final pedido = carrito.armarPedido(MetodoPago.debito);
      carrito.agregarProducto(yerba);

      expect(pedido.items.single.cantidad, 1);
    });

    test('cada pedido tiene un id distinto para Mercado Pago', () {
      carrito.agregarProducto(yerba);
      final primero = carrito.armarPedido(MetodoPago.debito);
      final segundo = carrito.armarPedido(MetodoPago.debito);

      expect(primero.id, isNot(segundo.id));
    });

    test('avisa a los listeners cuando cambia', () {
      var avisos = 0;
      carrito
        ..addListener(() => avisos++)
        ..agregarProducto(yerba)
        ..quitarProducto(yerba);

      expect(avisos, 2);
    });
  });

  test('formatearPrecio usa punto como separador de miles', () {
    expect(formatearPrecio(0), '\$0');
    expect(formatearPrecio(800), '\$800');
    expect(formatearPrecio(3800), '\$3.800');
    expect(formatearPrecio(1234567), '\$1.234.567');
  });
}
