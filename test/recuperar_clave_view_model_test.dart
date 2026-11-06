import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/sesion_repository.dart';
import 'package:freshmarket_app/ui/sesion/view_models/recuperar_clave_view_model.dart';

import 'fakes.dart';

void main() {
  late SesionServiceFalso service;
  late SesionRepository repositorio;
  late RecuperarClaveViewModel viewModel;

  setUp(() {
    service = SesionServiceFalso();
    repositorio = SesionRepository(service: service);
    viewModel = RecuperarClaveViewModel(repositorio: repositorio);
  });

  tearDown(() => viewModel.dispose());

  test('arranca con el email que ya se había escrito', () {
    final conEmail = RecuperarClaveViewModel(
      repositorio: repositorio,
      email: ' ceferino@x.com ',
    );
    expect(conEmail.email, 'ceferino@x.com');
    conEmail.dispose();
  });

  test('un email mal escrito no se manda', () async {
    await viewModel.enviarCodigo('ceferino-arroba-x');

    expect(viewModel.error, ErrorRecuperacion.emailInvalido);
    expect(viewModel.paso, PasoRecuperacion.pedirEmail);
    expect(service.codigosPedidos, isEmpty);
  });

  test('pide el código y pasa a escribir la contraseña nueva', () async {
    await viewModel.enviarCodigo('ceferino@x.com');

    expect(service.codigosPedidos, ['ceferino@x.com']);
    expect(viewModel.paso, PasoRecuperacion.cambiarClave);
  });

  test('con el código correcto cambia la contraseña y se puede ingresar',
      () async {
    await viewModel.enviarCodigo('ceferino@x.com');
    await viewModel.cambiarClave(
      codigo: '123456',
      claveNueva: 'nueva-clave',
      repetida: 'nueva-clave',
    );

    expect(viewModel.paso, PasoRecuperacion.lista);
    expect(await repositorio.ingresar('ceferino@x.com', 'nueva-clave'),
        isNotNull);
  });

  test('valida antes de molestar al servidor', () async {
    await viewModel.enviarCodigo('ceferino@x.com');

    await viewModel.cambiarClave(
      codigo: '12a',
      claveNueva: 'nueva-clave',
      repetida: 'nueva-clave',
    );
    expect(viewModel.error, ErrorRecuperacion.codigoInvalido);

    await viewModel.cambiarClave(
      codigo: '123456',
      claveNueva: 'corta',
      repetida: 'corta',
    );
    expect(viewModel.error, ErrorRecuperacion.claveCorta);

    await viewModel.cambiarClave(
      codigo: '123456',
      claveNueva: 'nueva-clave',
      repetida: 'otra-clave',
    );
    expect(viewModel.error, ErrorRecuperacion.clavesDistintas);
    expect(service.claves['ceferino@x.com'], 'clave-dueno');
  });

  test('un código equivocado avisa y deja probar otra vez', () async {
    await viewModel.enviarCodigo('ceferino@x.com');
    await viewModel.cambiarClave(
      codigo: '999999',
      claveNueva: 'nueva-clave',
      repetida: 'nueva-clave',
    );

    expect(viewModel.error, ErrorRecuperacion.codigoIncorrecto);
    expect(viewModel.paso, PasoRecuperacion.cambiarClave);
  });

  test('sin internet vuelve al paso del email y avisa', () async {
    service.sinConexion = true;

    await viewModel.enviarCodigo('ceferino@x.com');

    expect(viewModel.paso, PasoRecuperacion.pedirEmail);
    expect(viewModel.error, ErrorRecuperacion.sinConexion);
  });
}
