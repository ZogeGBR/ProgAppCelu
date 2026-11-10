// Segundo plano (recordatorio programado), eventos del sistema
// (conectividad) e historial que observa los pagos.
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/data/repositories/conectividad_repository.dart';
import 'package:freshmarket_app/data/repositories/historial_repository.dart';
import 'package:freshmarket_app/data/repositories/pago_repository.dart';
import 'package:freshmarket_app/data/repositories/recordatorios_repository.dart';
import 'package:freshmarket_app/data/services/conectividad_service.dart';
import 'package:freshmarket_app/data/services/historial_dao.dart';
import 'package:freshmarket_app/data/services/recordatorio_service.dart';
import 'package:freshmarket_app/domain/models/item_carrito.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/catalogo/view_models/catalogo_view_model.dart';
import 'package:freshmarket_app/ui/inicio/view_models/conectividad_view_model.dart';
import 'package:freshmarket_app/ui/seguimiento/view_models/historial_view_model.dart';

import 'fakes.dart';

void main() {
  group('recordatorio del carrito (segundo plano)', () {
    late RecordatorioServiceSimulado sistema;
    late CarritoViewModel carrito;
    final ahora = DateTime(2026, 11, 19, 10);

    setUp(() {
      sistema = RecordatorioServiceSimulado();
      carrito = CarritoViewModel(
        recordatorios: RecordatoriosRepository(
          service: sistema,
          reloj: () => ahora,
        ),
      );
    });

    test('al salir con el carrito lleno se programa para dentro de 2 horas',
        () async {
      carrito.agregarProducto(yerba);

      await carrito.alOcultarseLaApp();

      expect(
        sistema.programados[RecordatoriosRepository.idCarrito],
        ahora.add(const Duration(hours: 2)),
      );
    });

    test('con el carrito vacío no se programa nada', () async {
      await carrito.alOcultarseLaApp();

      expect(sistema.programados, isEmpty);
    });

    test('salir dos veces no duplica: mismo id, reemplaza', () async {
      carrito.agregarProducto(yerba);
      await carrito.alOcultarseLaApp();
      await carrito.alOcultarseLaApp();

      expect(sistema.programados, hasLength(1));
    });

    test('al volver a la app se cancela', () async {
      carrito.agregarProducto(yerba);
      await carrito.alOcultarseLaApp();

      await carrito.alVolverALaApp();

      expect(sistema.programados, isEmpty);
    });
  });

  group('conectividad (evento del sistema)', () {
    test('avisa al cortarse y al volver, sin repetir', () async {
      final red = ConectividadServiceSimulado();
      final viewModel = ConectividadViewModel(
        repositorio: ConectividadRepository(service: red),
      );
      addTearDown(viewModel.dispose);
      var avisos = 0;
      viewModel.addListener(() => avisos++);

      red
        ..cambiar(hayRed: false)
        ..cambiar(hayRed: false);
      await pumpEventQueue();
      expect(viewModel.hayRed, isFalse);

      red.cambiar(hayRed: true);
      await pumpEventQueue();
      expect(viewModel.hayRed, isTrue);
      expect(avisos, 2);
    });

    test('revisar() pregunta el estado actual', () async {
      final viewModel = ConectividadViewModel(
        repositorio: ConectividadRepository(
          service: ConectividadServiceSimulado(hayRed: false),
        ),
      );
      addTearDown(viewModel.dispose);

      await viewModel.revisar();

      expect(viewModel.hayRed, isFalse);
    });
  });

  group('historial', () {
    test('guarda solo cada pedido confirmado (Observer de los pagos)',
        () async {
      final pagos = PagoRepository(
        service: PagoServiceFalso(),
        checkout: CheckoutFalso(),
      );
      final memoria = HistorialServiceMemoria();
      final viewModel = HistorialViewModel(
        repositorio: HistorialRepository(service: memoria),
        pagos: pagos,
      );
      addTearDown(viewModel.dispose);
      final carrito = CarritoViewModel()..agregarProducto(queso);

      // En efectivo el pedido queda confirmado al registrarlo.
      await pagos.iniciarPago(
        carrito
            .armarPedido(MetodoPago.efectivo)
            .copiarCon(direccion: 'Belgrano 55'),
      );
      await pumpEventQueue();

      expect(viewModel.hayPedidos, isTrue);
      expect(viewModel.pedidos.single.total, 6500);
      expect(viewModel.cargando, isFalse);
    });

    test('"Volver a pedir" usa el precio de hoy y saca lo que no hay',
        () async {
      final service = CatalogoServiceFalso();
      // Hoy la yerba subió y el queso no hay.
      service.productos
        ..[0] = {...yerba.toJson(), 'precio': 4000}
        ..[2] = {...queso.toJson(), 'disponible': false};
      final catalogo = CatalogoViewModel(
        repositorio: CatalogoRepository(service: service),
      );
      addTearDown(catalogo.dispose);
      await catalogo.cargar();

      final hoy = catalogo.conPreciosDeHoy(const [
        ItemCarrito(producto: yerba, cantidad: 2),
        ItemCarrito(producto: queso),
      ]);

      expect(hoy.single.producto.precio, 4000);
      expect(hoy.single.cantidad, 2);
    });
  });
}
