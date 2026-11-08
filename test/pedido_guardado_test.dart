import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/seguimiento_repository.dart';
import 'package:freshmarket_app/data/services/pedido_local_service.dart';
import 'package:freshmarket_app/domain/models/estado_pedido.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/domain/models/pedido.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/seguimiento/view_models/seguimiento_view_model.dart';

import 'fakes.dart';

/// El pedido que se sigue queda guardado en el celular: si la app se
/// cierra (o se abre tocando "Tu pedido está en camino"), "Mi pedido" lo
/// retoma en vez de aparecer vacío.
void main() {
  late PedidoLocalServiceMemoria disco;
  late SeguimientoServiceFalso servicio;

  Pedido pedidoDePrueba() {
    final carrito = CarritoViewModel()
      ..agregarProducto(yerba)
      ..agregarProducto(yerba)
      ..agregarProducto(queso);
    return carrito.armarPedido(MetodoPago.efectivo).copiarCon(
          numero: 2057,
          direccion: 'Belgrano 55',
          destino: const Posicion(latitud: -32.88, longitud: -68.84),
        );
  }

  // Cada "apertura de la app" es un ViewModel nuevo con el mismo disco.
  SeguimientoViewModel abrirApp() {
    final viewModel = SeguimientoViewModel(
      repositorio: SeguimientoRepository(service: servicio, guardado: disco),
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  setUp(() {
    disco = PedidoLocalServiceMemoria();
    servicio = SeguimientoServiceFalso();
  });

  test('el pedido viaja al disco y vuelve igual (resumen incluido)', () {
    final pedido = pedidoDePrueba();

    final vuelta = Pedido.fromJsonLocal(pedido.toJsonLocal());

    expect(vuelta.id, pedido.id);
    expect(vuelta.numero, 2057);
    expect(vuelta.cantidadProductos, 3);
    expect(vuelta.total, pedido.total);
    expect(vuelta.metodoPago, MetodoPago.efectivo);
    expect(vuelta.direccion, 'Belgrano 55');
    expect(vuelta.destino, pedido.destino);
    expect(vuelta.fecha, pedido.fecha);
  });

  test('al cerrar y abrir la app, "Mi pedido" sigue el mismo pedido', () async {
    final pedido = pedidoDePrueba();
    abrirApp().seguir(pedido);
    await Future<void>.delayed(Duration.zero);

    final otraVez = abrirApp();
    await otraVez.restaurar();

    expect(otraVez.pedido?.id, pedido.id);
    expect(otraVez.pedido?.numero, 2057);
    expect(otraVez.estado, EstadoPedido.recibido);

    // Y vuelve a escuchar al repartidor.
    servicio.emitir({'estado': 'enPreparacion'});
    await Future<void>.delayed(Duration.zero);
    expect(otraVez.estado, EstadoPedido.enPreparacion);
  });

  test('"Hacer otro pedido" lo borra: al volver a abrir, está vacío', () async {
    final primera = abrirApp()..seguir(pedidoDePrueba());
    await Future<void>.delayed(Duration.zero);

    primera.terminar();
    await Future<void>.delayed(Duration.zero);

    final otraVez = abrirApp();
    await otraVez.restaurar();
    expect(otraVez.hayPedido, isFalse);
    expect(disco.guardado, isNull);
  });

  test('no pisa un pedido que ya se está siguiendo', () async {
    abrirApp().seguir(pedidoDePrueba());
    await Future<void>.delayed(Duration.zero);

    final viewModel = abrirApp();
    final nuevo = CarritoViewModel().armarPedido(MetodoPago.debito);
    viewModel.seguir(nuevo);
    await viewModel.restaurar();

    expect(viewModel.pedido?.id, nuevo.id);
  });

  test('si lo guardado está roto, arranca vacío y lo borra', () async {
    disco = PedidoLocalServiceMemoria('{"esto": "no es un pedido"}');

    final viewModel = abrirApp();
    await viewModel.restaurar();

    expect(viewModel.hayPedido, isFalse);
    expect(disco.guardado, isNull);
  });

  test('sin disco (pruebas viejas) no hace nada', () async {
    final viewModel = SeguimientoViewModel(
      repositorio: SeguimientoRepository(service: servicio),
    );
    addTearDown(viewModel.dispose);

    await viewModel.restaurar();
    viewModel.seguir(pedidoDePrueba());

    expect(viewModel.hayPedido, isTrue);
  });
}
