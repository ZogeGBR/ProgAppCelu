import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/carrito_repository.dart';
import 'package:freshmarket_app/data/repositories/pago_repository.dart';
import 'package:freshmarket_app/data/services/carrito_local_service.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/pago/view_models/pago_view_model.dart';

import 'fakes.dart';

void main() {
  group('carrito guardado en el celular', () {
    late CarritoLocalServiceMemoria disco;

    CarritoViewModel nuevoCarrito() => CarritoViewModel(
          repositorio: CarritoRepository(service: disco),
        );

    setUp(() => disco = CarritoLocalServiceMemoria());

    test('lo que se guarda vuelve al abrir la app otra vez', () async {
      final antes = nuevoCarrito()
        ..agregarProducto(yerba)
        ..agregarProducto(yerba)
        ..agregarProducto(queso);
      await antes.guardar();

      final despues = nuevoCarrito();
      await despues.restaurar();

      expect(despues.cantidadDe(yerba), 2);
      expect(despues.cantidadDe(queso), 1);
      expect(despues.total, antes.total);
    });

    test('no pisa lo que la persona ya agregó', () async {
      final viejo = nuevoCarrito()..agregarProducto(queso);
      await viejo.guardar();

      final carrito = nuevoCarrito()..agregarProducto(leche);
      await carrito.restaurar();

      expect(carrito.cantidadDe(leche), 1);
      expect(carrito.cantidadDe(queso), 0);
    });

    test('si lo guardado está roto, arranca vacío sin romperse', () async {
      disco = CarritoLocalServiceMemoria('esto no es json');

      final carrito = nuevoCarrito();
      await carrito.restaurar();

      expect(carrito.estaVacio, isTrue);
    });

    test('sin repositorio (pruebas viejas) no hace nada', () async {
      final carrito = CarritoViewModel()..agregarProducto(yerba);

      await carrito.guardar();
      await carrito.restaurar();

      expect(carrito.cantidadDe(yerba), 1);
    });
  });

  test('marcar en el mapa completa la dirección del pedido', () {
    final pago = PagoViewModel(
      repositorio: PagoRepository(
        service: PagoServiceFalso(),
        checkout: CheckoutFalso(),
      ),
      armarPedido: CarritoViewModel().armarPedido,
      alAprobar: (_) {},
    );
    const casa = Posicion(latitud: -32.88, longitud: -68.84);

    pago.marcarDestino(casa, direccion: ' Belgrano 55, Mendoza ');
    expect(pago.destino, casa);
    expect(pago.direccion, 'Belgrano 55, Mendoza');

    // Si el mapa no encontró calle, no borra lo que la persona escribió.
    pago
      ..cambiarDireccion('Belgrano 55, timbre 2')
      ..marcarDestino(casa);
    expect(pago.direccion, 'Belgrano 55, timbre 2');
    pago.dispose();
  });
}
