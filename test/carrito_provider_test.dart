import 'package:flutter_test/flutter_test.dart';

import 'package:freshmarket_app/models/metodo_pago.dart';
import 'package:freshmarket_app/models/producto.dart';
import 'package:freshmarket_app/providers/carrito_provider.dart';
import 'package:freshmarket_app/utils/formato.dart';

void main() {
  final yerba = catalogoFreshMarket.firstWhere((p) => p.id == 'p2'); // 3800
  final leche = catalogoFreshMarket.firstWhere((p) => p.id == 'p3'); // 1500

  group('CarritoProvider', () {
    late CarritoProvider carrito;

    setUp(() => carrito = CarritoProvider());

    test('agregar el mismo producto suma cantidad en vez de duplicarlo', () {
      carrito.agregarProducto(yerba);
      carrito.agregarProducto(yerba);
      carrito.agregarProducto(leche);

      expect(carrito.items.length, 2);
      expect(carrito.cantidadDe(yerba), 2);
      expect(carrito.cantidadTotal, 3);
      expect(carrito.total, 3800 * 2 + 1500);
    });

    test('quitar hasta 0 saca el producto del carrito', () {
      carrito.agregarProducto(leche);
      carrito.quitarProducto(leche);

      expect(carrito.estaVacio, isTrue);
    });

    test('eliminarProducto saca el ítem entero', () {
      carrito.agregarProducto(yerba);
      carrito.agregarProducto(yerba);
      carrito.eliminarProducto(yerba);

      expect(carrito.cantidadDe(yerba), 0);
    });

    test('confirmarPedido guarda una copia y vacía el carrito', () {
      carrito.agregarProducto(yerba);
      carrito.agregarProducto(leche);

      final pedido = carrito.confirmarPedido(MetodoPago.mercadoPago);

      expect(carrito.estaVacio, isTrue);
      expect(pedido.total, 5300);
      expect(pedido.cantidadProductos, 2);
      expect(pedido.metodoPago, MetodoPago.mercadoPago);

      final siguiente = carrito.confirmarPedido(MetodoPago.tarjeta);
      expect(siguiente.numero, pedido.numero + 1);
    });

    test('avisa a los listeners cuando cambia', () {
      var avisos = 0;
      carrito.addListener(() => avisos++);

      carrito.agregarProducto(yerba);
      carrito.quitarProducto(yerba);

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
