import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/pago_repository.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/domain/models/pedido.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/pago/view_models/pago_view_model.dart';

import 'fakes.dart';

void main() {
  const intervalo = Duration(milliseconds: 10);

  late CarritoViewModel carrito;
  late PagoServiceFalso service;
  late CheckoutFalso checkout;
  late PagoViewModel viewModel;
  Pedido? aprobado;

  void crear({
    List<String> respuestas = const ['aprobado'],
    bool seAbre = true,
    Duration limite = const Duration(seconds: 5),
    int? numero,
    bool conDireccion = true,
  }) {
    carrito = CarritoViewModel()..agregarProducto(yerba);
    service = PagoServiceFalso(respuestas: respuestas, numero: numero);
    checkout = CheckoutFalso(seAbre: seAbre);
    aprobado = null;
    final repositorio = PagoRepository(
      service: service,
      checkout: checkout,
      intervaloConsulta: intervalo,
      limiteEspera: limite,
    );
    // Observer: el repositorio publica el pedido confirmado.
    repositorio.pedidosConfirmados.listen((pedido) => aprobado = pedido);
    viewModel = PagoViewModel(
      repositorio: repositorio,
      armarPedido: carrito.armarPedido,
    );
    if (conDireccion) viewModel.cambiarDireccion('San Martín 1234');
  }

  /// Espera a que el ViewModel deje de estar ocupado.
  Future<void> esperarResultado() async {
    while (viewModel.estaOcupado) {
      await Future<void>.delayed(intervalo);
    }
  }

  tearDown(() => viewModel.dispose());

  test('no se puede pagar sin elegir el medio de pago', () async {
    crear();
    expect(viewModel.puedePagar, isFalse);

    await viewModel.pagar();

    expect(service.pedidosEnviados, isEmpty);
  });

  test('no se puede pagar sin escribir la dirección', () async {
    crear(conDireccion: false);
    viewModel
      ..elegirMetodo(MetodoPago.debito)
      ..cambiarDireccion('   ');
    expect(viewModel.puedePagar, isFalse);

    await viewModel.pagar();

    expect(service.pedidosEnviados, isEmpty);
  });

  test('el pedido viaja con la dirección y el punto del mapa', () async {
    crear();
    const casa = Posicion(latitud: -32.9, longitud: -68.85);
    viewModel
      ..elegirMetodo(MetodoPago.debito)
      ..cambiarDireccion('  Belgrano 55 ')
      ..marcarDestino(casa);

    await viewModel.pagar();
    await esperarResultado();

    final enviado = service.pedidosEnviados.single;
    expect(enviado['direccion'], 'Belgrano 55');
    expect(enviado['destino'], {'lat': -32.9, 'lng': -68.85});
    expect(aprobado?.destino, casa);
  });

  test('el número de pedido lo asigna el servidor', () async {
    crear(numero: 2057);
    viewModel.elegirMetodo(MetodoPago.debito);

    await viewModel.pagar();
    await esperarResultado();

    expect(aprobado?.numero, 2057);
  });

  test('en efectivo se confirma sin abrir Mercado Pago', () async {
    crear(respuestas: ['pendiente']);
    viewModel.elegirMetodo(MetodoPago.efectivo);

    await viewModel.pagar();

    expect(viewModel.paso, PasoPago.aprobado);
    expect(checkout.abiertos, isEmpty);
    expect(aprobado?.metodoPago, MetodoPago.efectivo);
    expect(service.pedidosEnviados.single['metodoPago'], 'efectivo');
  });

  test('pago aprobado: abre Mercado Pago y avisa con el pedido', () async {
    crear(respuestas: ['pendiente', 'pendiente', 'aprobado']);
    viewModel.elegirMetodo(MetodoPago.debito);

    await viewModel.pagar();
    expect(viewModel.paso, PasoPago.esperandoConfirmacion);
    await esperarResultado();

    expect(viewModel.paso, PasoPago.aprobado);
    expect(checkout.abiertos.single.toString(), 'https://mp.test/pagar');
    expect(aprobado?.metodoPago, MetodoPago.debito);
    expect(service.pedidosEnviados.single['metodoPago'], 'debito');
  });

  test('pago rechazado: no avisa y deja volver a elegir', () async {
    crear(respuestas: ['rechazado']);
    viewModel.elegirMetodo(MetodoPago.credito);

    await viewModel.pagar();
    await esperarResultado();

    expect(viewModel.paso, PasoPago.rechazado);
    expect(aprobado, isNull);

    viewModel.volverAElegir();
    expect(viewModel.paso, PasoPago.eligiendo);
  });

  test('si el backend falla al crear el pago, muestra error', () async {
    crear();
    service.fallaAlCrear = true;
    viewModel.elegirMetodo(MetodoPago.billeteraMercadoPago);

    await viewModel.pagar();

    expect(viewModel.paso, PasoPago.error);
    expect(checkout.abiertos, isEmpty);
  });

  test('si no se puede abrir Mercado Pago, muestra error', () async {
    crear(seAbre: false);
    viewModel.elegirMetodo(MetodoPago.debito);

    await viewModel.pagar();

    expect(viewModel.paso, PasoPago.error);
  });

  test('si nunca llega la confirmación, se rinde al pasar el límite', () async {
    crear(respuestas: ['pendiente'], limite: intervalo * 3);
    viewModel.elegirMetodo(MetodoPago.debito);

    await viewModel.pagar();
    await esperarResultado();

    expect(viewModel.paso, PasoPago.sinConfirmar);
    expect(aprobado, isNull);
  });
}
