import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/seguimiento_repository.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
import 'package:freshmarket_app/domain/models/estado_pedido.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/seguimiento/view_models/seguimiento_view_model.dart';

import 'fakes.dart';

void main() {
  late SeguimientoServiceFalso service;
  late SeguimientoViewModel viewModel;

  setUp(() {
    service = SeguimientoServiceFalso();
    viewModel = SeguimientoViewModel(
      repositorio: SeguimientoRepository(service: service),
    );
    final carrito = CarritoViewModel()..agregarProducto(yerba);
    viewModel.seguir(carrito.armarPedido(MetodoPago.debito));
  });

  tearDown(() => viewModel.dispose());

  // Deja que el stream entregue lo que se emitió.
  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  test('el destino que marcó el cliente llega al servicio', () {
    final carrito = CarritoViewModel()..agregarProducto(yerba);
    final pedido = carrito.armarPedido(MetodoPago.debito).copiarCon(
          destino: const Posicion(latitud: -32.9, longitud: -68.85),
        );

    viewModel.seguir(pedido);

    expect(service.ultimoDestino, {'lat': -32.9, 'lng': -68.85});
  });

  test('la demo nunca dice "0 min" mientras la bici está en camino', () async {
    const simulado = SeguimientoServiceSimulado(
      intervalo: Duration(milliseconds: 1),
    );

    final novedades = await simulado.seguirPedido('p').toList();
    final enCamino = novedades.where((n) => n['estado'] == 'enCamino');

    expect(enCamino, isNotEmpty);
    expect(enCamino.every((n) => (n['minutosEstimados'] as int) >= 1), isTrue);
  });

  test('arranca en "recibido" y sin mapa', () {
    expect(viewModel.hayPedido, isTrue);
    expect(viewModel.estado, EstadoPedido.recibido);
    expect(viewModel.mostrarMapa, isFalse);
  });

  test('en camino muestra el mapa con la bici del repartidor', () async {
    service.emitir({
      'estado': 'enCamino',
      'repartidor': {'nombre': 'Male', 'lat': -32.88, 'lng': -68.84},
      'destino': {'lat': -32.87, 'lng': -68.83},
      'minutosEstimados': 7,
    });
    await esperar();

    expect(viewModel.mostrarMapa, isTrue);
    expect(
      viewModel.posicionRepartidor,
      const Posicion(latitud: -32.88, longitud: -68.84),
    );
    expect(viewModel.nombreRepartidor, 'Male');
    expect(viewModel.minutosEstimados, 7);
  });

  test('un corte de señal avisa pero no termina el seguimiento', () async {
    service.fallar();
    await esperar();
    expect(viewModel.sinConexion, isTrue);

    service.emitir({'estado': 'enPreparacion'});
    await esperar();
    expect(viewModel.sinConexion, isFalse);
    expect(viewModel.estado, EstadoPedido.enPreparacion);
  });

  test('al entregarse deja de escuchar y se puede terminar', () async {
    service.emitir({'estado': 'entregado'});
    await esperar();
    expect(viewModel.entregado, isTrue);

    service.emitir({'estado': 'enCamino'});
    await esperar();
    expect(viewModel.entregado, isTrue);

    viewModel.terminar();
    expect(viewModel.hayPedido, isFalse);
  });
}
