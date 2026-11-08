import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/data/repositories/etiquetado_repository.dart';
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
    expect(viewModel.ficha?.precio, 3200);
    expect(catalogo.guardados, isEmpty);
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
