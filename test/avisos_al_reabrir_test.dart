import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/seguimiento_repository.dart';
import 'package:freshmarket_app/data/services/pedido_local_service.dart';
import 'package:freshmarket_app/data/services/push_service.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
import 'package:freshmarket_app/domain/models/aviso.dart';
import 'package:freshmarket_app/domain/models/estado_pedido.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/seguimiento/view_models/seguimiento_view_model.dart';

import 'fakes.dart';

/// Lo que encontró Matías en el celular: al abrir la app llegaban "Tu
/// pedido está en camino" y "Tu pedido llegó" de un pedido que ya había
/// terminado. El simulador volvía a empezar el reparto de cero; ahora
/// sigue desde donde iba, como un servidor de verdad.
void main() {
  final inicio = DateTime(2026, 11, 20, 16, 18);
  late PushServiceSimulado push;
  late List<Aviso> avisos;

  setUp(() {
    push = PushServiceSimulado();
    avisos = [];
    push.recibidos.listen(avisos.add);
  });

  // pasosEnCamino 4: eventos 0 (recibido) a 6 (entregado).
  SeguimientoServiceSimulado simulador({
    required Duration intervalo,
    required DateTime ahora,
  }) =>
      SeguimientoServiceSimulado(
        intervalo: intervalo,
        pasosEnCamino: 4,
        push: push,
        ahora: () => ahora,
      );

  List<String> titulos() => [for (final aviso in avisos) aviso.titulo];

  test('pedido recién pagado: avisa al salir y al llegar, como siempre',
      () async {
    final service = simulador(
      intervalo: const Duration(milliseconds: 1),
      ahora: inicio,
    );

    final eventos = await service.seguirPedido('p-1').toList();
    await Future<void>.delayed(Duration.zero);

    expect(eventos.first['estado'], 'recibido');
    expect(eventos.last['estado'], 'entregado');
    expect(titulos(), ['Tu pedido está en camino', 'Tu pedido llegó']);
  });

  test('ya había llegado: al reabrir dice "entregado" y no avisa nada',
      () async {
    final service = simulador(
      intervalo: const Duration(seconds: 2),
      ahora: inicio.add(const Duration(hours: 1)),
    );

    final eventos = await service.seguirPedido('p-1', desde: inicio).toList();
    await Future<void>.delayed(Duration.zero);

    expect(eventos.map((e) => e['estado']), ['entregado']);
    expect(avisos, isEmpty);
  });

  test('iba en camino: retoma en el mapa y solo avisa cuando llega', () async {
    const intervalo = Duration(milliseconds: 5);
    // Pasaron 3 intervalos: ya se mostró el evento 2 (salió la bici).
    final service = simulador(
      intervalo: intervalo,
      ahora: inicio.add(intervalo * 3),
    );

    final eventos = await service.seguirPedido('p-1', desde: inicio).toList();
    await Future<void>.delayed(Duration.zero);

    expect(eventos.first['estado'], 'enCamino');
    expect(eventos.last['estado'], 'entregado');
    expect(eventos.where((e) => e['estado'] == 'recibido'), isEmpty);
    expect(titulos(), ['Tu pedido llegó']);
  });

  test('de punta a punta: cerrar la app, volver horas después y abrirla',
      () async {
    final disco = PedidoLocalServiceMemoria();
    final pedido = (CarritoViewModel()..agregarProducto(yerba))
        .armarPedido(MetodoPago.efectivo);

    // Primera vez: se paga el pedido y queda guardado con la hora.
    await SeguimientoRepository(
      service: SeguimientoServiceFalso(),
      guardado: disco,
      ahora: () => inicio,
    ).recordar(pedido);

    // Una hora después se abre la app (el pedido llegó hace rato).
    final viewModel = SeguimientoViewModel(
      repositorio: SeguimientoRepository(
        service: simulador(
          intervalo: const Duration(seconds: 2),
          ahora: inicio.add(const Duration(hours: 1)),
        ),
        guardado: disco,
      ),
    );
    addTearDown(viewModel.dispose);

    await viewModel.restaurar();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(viewModel.pedido?.id, pedido.id);
    expect(viewModel.estado, EstadoPedido.entregado);
    expect(avisos, isEmpty);
  });

  test('lo guardado por una versión vieja (sin la hora) usa la del pedido',
      () async {
    final pedido = CarritoViewModel().armarPedido(MetodoPago.debito);
    final servicio = SeguimientoServiceFalso();
    final disco = PedidoLocalServiceMemoria();
    final repositorio =
        SeguimientoRepository(service: servicio, guardado: disco);
    await disco.guardar(
      '{"id":"${pedido.id}","numero":${pedido.numero},"items":[],'
      '"metodoPago":"debito","fecha":"${pedido.fecha.toIso8601String()}"}',
    );

    final guardado = await repositorio.pedidoGuardado();

    expect(guardado?.pedido.id, pedido.id);
    expect(guardado?.desde, pedido.fecha);
  });
}
