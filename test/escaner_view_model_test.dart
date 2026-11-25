import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/data/repositories/etiquetado_repository.dart';
import 'package:freshmarket_app/data/services/camara_service.dart';
import 'package:freshmarket_app/domain/models/error_de_foto.dart';
import 'package:freshmarket_app/ui/escaner/view_models/escaner_view_model.dart';

import 'fakes.dart';

void main() {
  late CamaraFalsa camara;
  late EtiquetadoServiceFalso etiquetado;
  late CatalogoServiceFalso catalogo;
  late EscanerViewModel viewModel;
  late int avisosDeGuardado;

  setUp(() async {
    camara = CamaraFalsa(foto: Uint8List.fromList([1, 2, 3]));
    etiquetado = EtiquetadoServiceFalso();
    catalogo = CatalogoServiceFalso();
    avisosDeGuardado = 0;
    final repositorio = CatalogoRepository(service: catalogo);
    await repositorio.obtenerProductos();
    // Observer: cuenta cuántas veces el catálogo avisó que cambió.
    repositorio.cambios.listen((_) => avisosDeGuardado++);
    viewModel = EscanerViewModel(
      etiquetado: EtiquetadoRepository(camara: camara, etiquetado: etiquetado),
      catalogo: repositorio,
    );
  });

  tearDown(() => viewModel.dispose());

  test('la foto se convierte en una ficha para revisar, sin guardar', () async {
    await viewModel.sacarFoto();

    expect(viewModel.paso, PasoEscaner.revisando);
    expect(viewModel.ficha?.nombre, 'Aceite de girasol 1.5L');
    expect(catalogo.guardados, isEmpty);
  });

  test('el precio no viene de la foto: lo pone el dueño', () async {
    // Aunque la IA sugiera un precio (la simulada sugiere 3200), la ficha
    // arranca sin precio y no se puede guardar hasta que el dueño lo pone.
    await viewModel.sacarFoto();

    expect(viewModel.ficha?.precio, 0);
    expect(viewModel.puedeGuardar, isFalse);

    viewModel.cambiarPrecio('2.990');
    expect(viewModel.ficha?.precio, 2990);
    expect(viewModel.puedeGuardar, isTrue);
  });

  group('cámara, como dice el apunte', () {
    test('cancelar no es un error: no muestra mensaje', () async {
      camara.foto = null;

      await viewModel.sacarFoto();

      expect(viewModel.paso, PasoEscaner.inicio);
      expect(viewModel.mensajeError, isNull);
    });

    test('un permiso negado muestra el motivo, sin romperse', () async {
      camara.error = const ErrorDeFoto('No tenemos permiso para usar la cámara.');

      await viewModel.sacarFoto();

      expect(viewModel.paso, PasoEscaner.error);
      expect(viewModel.mensajeError, contains('permiso'));

      viewModel.empezarDeNuevo();
      expect(viewModel.mensajeError, isNull);
    });

    test('dos toques rápidos no abren la cámara dos veces', () async {
      await Future.wait([viewModel.sacarFoto(), viewModel.sacarFoto()]);

      expect(camara.vecesAbierta, 1);
    });

    test('si Android cerró la app con la cámara abierta, la foto vuelve',
        () async {
      camara.perdida = Uint8List.fromList([9, 9, 9]);

      await viewModel.recuperarFotoPerdida();

      expect(viewModel.paso, PasoEscaner.revisando);
      expect(viewModel.foto, [9, 9, 9]);
    });

    test('sin foto perdida, al abrir no cambia nada', () async {
      await viewModel.recuperarFotoPerdida();

      expect(viewModel.paso, PasoEscaner.inicio);
    });

    test('cada código de error tiene su mensaje para la persona', () {
      expect(
        CamaraServiceImagePicker.mensajePara(
          'camera_access_denied',
          deGaleria: false,
        ),
        contains('permiso para usar la cámara'),
      );
      expect(
        CamaraServiceImagePicker.mensajePara('otro', deGaleria: true),
        contains('tus fotos'),
      );
    });
  });

  test('si cancela la cámara no pasa nada', () async {
    camara.foto = null;

    await viewModel.sacarFoto();

    expect(viewModel.paso, PasoEscaner.inicio);
  });

  test('el dueño corrige el precio y recién ahí se guarda', () async {
    await viewModel.sacarFoto();
    viewModel
      ..cambiarPrecio('\$ 3.450')
      ..cambiarCategoria('Otros');

    await viewModel.guardar();

    expect(viewModel.paso, PasoEscaner.guardado);
    expect(catalogo.guardados.single['precio'], 3450);
    expect(catalogo.guardados.single['categoria'], 'Otros');
    expect(avisosDeGuardado, 1);
  });

  test('sin nombre o sin precio no se puede guardar', () async {
    await viewModel.sacarFoto();
    viewModel.cambiarPrecio('');

    expect(viewModel.puedeGuardar, isFalse);
    await viewModel.guardar();
    expect(catalogo.guardados, isEmpty);
  });

  test('si la IA falla muestra error y se puede empezar de nuevo', () async {
    etiquetado.falla = true;

    await viewModel.sacarFoto();
    expect(viewModel.paso, PasoEscaner.error);

    viewModel.empezarDeNuevo();
    expect(viewModel.paso, PasoEscaner.inicio);
  });
}
