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

  test('cada cuenta entra con su rol, su nombre y guarda el token', () async {
    await viewModel.ingresar('ceferino@x.com', 'clave-dueno');
    expect(viewModel.rol, Rol.dueno);
    expect(viewModel.nombre, 'Don Ceferino');
    expect(token, 'token-dueno');

    await viewModel.ingresar('  tobias@x.com ', 'clave-reparto');
    expect(viewModel.rol, Rol.repartidor);
    expect(token, 'token-reparto');
  });

  test('una contraseña mala no entra', () async {
    await viewModel.ingresar('ceferino@x.com', 'cualquiera');

    expect(viewModel.haySesion, isFalse);
    expect(viewModel.estado, EstadoIngreso.datosIncorrectos);
    expect(token, isNull);
  });

  test('la contraseña no se recorta: un espacio es parte de ella', () async {
    await viewModel.ingresar('ceferino@x.com', ' clave-dueno ');

    expect(viewModel.estado, EstadoIngreso.datosIncorrectos);
  });

  test('sin internet no dice que los datos están mal', () async {
    service.sinConexion = true;

    await viewModel.ingresar('ceferino@x.com', 'clave-dueno');

    expect(viewModel.estado, EstadoIngreso.sinConexion);
  });

  test('con el email o la contraseña vacíos ni se intenta', () async {
    await viewModel.ingresar('   ', 'clave-dueno');
    await viewModel.ingresar('ceferino@x.com', '');

    expect(viewModel.estado, EstadoIngreso.esperando);
  });

  test('salir borra la sesión y el token', () async {
    await viewModel.ingresar('ceferino@x.com', 'clave-dueno');

    viewModel.salir();

    expect(viewModel.haySesion, isFalse);
    expect(token, isNull);
  });
}
