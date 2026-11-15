import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/reparto_repository.dart';
import 'package:freshmarket_app/data/services/ubicacion_service.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/reparto/view_models/reparto_view_model.dart';

import 'fakes.dart';

void main() {
  const punto = Posicion(latitud: -32.885, longitud: -68.84);

  late RepartoServiceFalso service;
  late UbicacionFalsa ubicacion;
  late RepartoViewModel viewModel;

  setUp(() {
    service = RepartoServiceFalso();
    ubicacion = UbicacionFalsa();
    viewModel = RepartoViewModel(
      repositorio: RepartoRepository(service: service, ubicacion: ubicacion),
    );
  });

  tearDown(() => viewModel.dispose());

  // Deja que el stream entregue lo que se emitió.
  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  test('muestra los pedidos y si hay que cobrar', () async {
    await viewModel.cargar();

    expect(viewModel.paso, PasoReparto.eligiendo);
    expect(viewModel.pedidos.single.direccion, 'Belgrano 55');
    expect(viewModel.pedidos.single.hayQueCobrar, isTrue);
  });

  test('si no se pueden traer los pedidos, muestra error', () async {
    service.falla = true;

    await viewModel.cargar();

    expect(viewModel.paso, PasoReparto.error);
  });

  test('sin permiso o con el GPS apagado no empieza', () async {
    await viewModel.cargar();

    ubicacion.permiso = PermisoUbicacion.denegado;
    await viewModel.empezar(viewModel.pedidos.single);
    expect(viewModel.paso, PasoReparto.sinPermiso);

    ubicacion.permiso = PermisoUbicacion.gpsApagado;
    await viewModel.empezar(viewModel.pedidos.single);
    expect(viewModel.paso, PasoReparto.gpsApagado);
    expect(ubicacion.hayQuienEscuche, isFalse);
  });

  test('al moverse manda la posición del pedido que lleva', () async {
    await viewModel.cargar();
    await viewModel.empezar(viewModel.pedidos.single);
    expect(viewModel.paso, PasoReparto.repartiendo);

    ubicacion.mover(punto);
    await esperar();

    expect(viewModel.posicion, punto);
    expect(service.posiciones.single['pedidoId'], 'r-1');
    expect(service.posiciones.single['lat'], -32.885);
  });

  test('un corte de señal avisa y sigue con la próxima posición', () async {
    await viewModel.cargar();
    await viewModel.empezar(viewModel.pedidos.single);

    service.falla = true;
    ubicacion.mover(punto);
    await esperar();
    expect(viewModel.sinConexion, isTrue);
    expect(viewModel.paso, PasoReparto.repartiendo);

    service.falla = false;
    ubicacion.mover(punto);
    await esperar();
    expect(viewModel.sinConexion, isFalse);
    expect(service.posiciones.length, 1);
  });

  test('al entregar apaga el GPS y saca el pedido de la lista', () async {
    await viewModel.cargar();
    await viewModel.empezar(viewModel.pedidos.single);

    await viewModel.entregar();

    expect(service.entregados, ['r-1']);
    expect(viewModel.pedidos, isEmpty);
    expect(viewModel.paso, PasoReparto.eligiendo);
    expect(ubicacion.hayQuienEscuche, isFalse);
  });

  test('si falla la entrega, sigue repartiendo y avisa', () async {
    await viewModel.cargar();
    await viewModel.empezar(viewModel.pedidos.single);

    service.falla = true;
    await viewModel.entregar();

    expect(viewModel.paso, PasoReparto.repartiendo);
    expect(viewModel.sinConexion, isTrue);
    expect(viewModel.entregando, isFalse);
  });

  test('cerrar la sesión apaga el GPS', () async {
    await viewModel.cargar();
    await viewModel.empezar(viewModel.pedidos.single);

    viewModel.detener();

    expect(ubicacion.hayQuienEscuche, isFalse);
  });
}
