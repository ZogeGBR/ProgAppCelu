import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/ubicacion_entrega_repository.dart';
import 'package:freshmarket_app/data/services/ubicacion_service.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/ui/pago/view_models/elegir_ubicacion_view_model.dart';

import 'fakes.dart';

void main() {
  late GeocodificacionFalsa geocodificacion;
  late UbicacionFalsa gps;
  late UbicacionEntregaRepository repositorio;
  late ElegirUbicacionViewModel viewModel;

  const casa = Posicion(latitud: -32.881, longitud: -68.84);

  setUp(() {
    geocodificacion = GeocodificacionFalsa();
    gps = UbicacionFalsa();
    repositorio = UbicacionEntregaRepository(
      geocodificacion: geocodificacion,
      gps: gps,
    );
    viewModel = ElegirUbicacionViewModel(repositorio: repositorio);
  });

  tearDown(() => viewModel.dispose());

  test('sin tocar el mapa no se puede confirmar', () {
    expect(viewModel.estado, EstadoUbicacion.sinMarcar);
    expect(viewModel.puedeConfirmar, isFalse);
    expect(viewModel.resultado, isNull);
  });

  test('al tocar el mapa trae la dirección de ese punto', () async {
    await viewModel.marcar(casa);

    expect(viewModel.estado, EstadoUbicacion.conDireccion);
    expect(viewModel.direccion, 'Calle -32.881');
    expect(viewModel.resultado?.posicion, casa);
    expect(viewModel.resultado?.direccion, 'Calle -32.881');
  });

  test('mientras busca la dirección no se puede confirmar', () async {
    final busqueda = viewModel.marcar(casa);

    expect(viewModel.estado, EstadoUbicacion.buscandoDireccion);
    expect(viewModel.puedeConfirmar, isFalse);
    await busqueda;
  });

  test('si toca dos veces rápido, vale el último toque', () async {
    const primero = Posicion(latitud: -32.1, longitud: -68.8);
    const segundo = Posicion(latitud: -32.2, longitud: -68.8);
    geocodificacion.demoras[-32.1] = const Duration(milliseconds: 50);

    final lento = viewModel.marcar(primero);
    await viewModel.marcar(segundo);
    await lento;

    expect(viewModel.punto, segundo);
    expect(viewModel.direccion, 'Calle -32.2');
  });

  test('el mismo lugar no se consulta dos veces (caché)', () async {
    await viewModel.marcar(casa);
    await viewModel
        .marcar(const Posicion(latitud: -32.88101, longitud: -68.84));

    expect(geocodificacion.consultas, 1);
  });

  test('si no hay calle o falla, igual se puede confirmar el punto', () async {
    geocodificacion.direccionFija = '';
    await viewModel.marcar(casa);
    expect(viewModel.estado, EstadoUbicacion.sinCalle);
    expect(viewModel.puedeConfirmar, isTrue);

    geocodificacion.falla = true;
    await viewModel.marcar(const Posicion(latitud: -32.9, longitud: -68.9));
    expect(viewModel.estado, EstadoUbicacion.error);
    expect(viewModel.puedeConfirmar, isTrue);
  });

  test('"Usar mi ubicación" marca donde está el celular', () async {
    await viewModel.usarMiUbicacion();

    expect(viewModel.punto, gps.actual);
    expect(viewModel.estado, EstadoUbicacion.conDireccion);
    expect(viewModel.sinGps, isFalse);
  });

  test('sin permiso de GPS avisa y no marca nada', () async {
    gps.permiso = PermisoUbicacion.denegado;

    await viewModel.usarMiUbicacion();

    expect(viewModel.sinGps, isTrue);
    expect(viewModel.punto, isNull);
  });
}
