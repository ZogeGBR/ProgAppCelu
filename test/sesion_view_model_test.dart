import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/sesion_repository.dart';
import 'package:freshmarket_app/domain/models/sesion.dart';
import 'package:freshmarket_app/ui/sesion/view_models/sesion_view_model.dart';

import 'fakes.dart';

void main() {
  late SesionServiceFalso service;
  late SesionViewModel viewModel;
  String? token;

  setUp(() {
    token = null;
    service = SesionServiceFalso();
    viewModel = SesionViewModel(
      repositorio: SesionRepository(
        service: service,
        alCambiarToken: (nuevo) => token = nuevo,
      ),
    );
  });

  tearDown(() => viewModel.dispose());

  test('sin ingresar es un cliente', () {
    expect(viewModel.haySesion, isFalse);
    expect(viewModel.esDueno, isFalse);
    expect(viewModel.esRepartidor, isFalse);
  });

  test('cada clave entra con su rol y guarda el token', () async {
    await viewModel.ingresar('clave-dueno');
    expect(viewModel.rol, Rol.dueno);
    expect(token, 'token-dueno');

    await viewModel.ingresar('  clave-reparto ');
    expect(viewModel.rol, Rol.repartidor);
    expect(token, 'token-reparto');
  });

  test('una clave mala no entra', () async {
    await viewModel.ingresar('cualquiera');

    expect(viewModel.haySesion, isFalse);
    expect(viewModel.estado, EstadoIngreso.claveIncorrecta);
    expect(token, isNull);
  });

  test('sin internet no dice que la clave está mal', () async {
    service.sinConexion = true;

    await viewModel.ingresar('clave-dueno');

    expect(viewModel.estado, EstadoIngreso.sinConexion);
  });

  test('una clave vacía ni se intenta', () async {
    await viewModel.ingresar('   ');

    expect(viewModel.estado, EstadoIngreso.esperando);
  });

  test('salir borra la sesión y el token', () async {
    await viewModel.ingresar('clave-dueno');

    viewModel.salir();

    expect(viewModel.haySesion, isFalse);
    expect(token, isNull);
  });
}
