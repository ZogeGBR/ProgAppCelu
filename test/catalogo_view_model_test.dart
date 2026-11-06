import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/ui/catalogo/view_models/catalogo_view_model.dart';
import 'package:freshmarket_app/ui/core/estado_carga.dart';

import 'fakes.dart';

void main() {
  late CatalogoServiceFalso service;
  late CatalogoViewModel viewModel;

  void crear({int fallas = 0}) {
    service = CatalogoServiceFalso(fallasAntesDeResponder: fallas);
    viewModel = CatalogoViewModel(
      repositorio: CatalogoRepository(service: service),
    );
  }

  test('arranca cargando y termina con los productos', () async {
    crear();
    expect(viewModel.estado, EstadoCarga.cargando);

    await viewModel.cargar();

    expect(viewModel.estado, EstadoCarga.exito);
    expect(viewModel.productosVisibles.length, 3);
  });

  test('si el servidor falla una vez, el repositorio reintenta solo', () async {
    crear(fallas: 1);

    await viewModel.cargar();

    expect(viewModel.estado, EstadoCarga.exito);
    expect(service.llamadas, 2);
  });

  test('si falla dos veces muestra error y se puede reintentar', () async {
    crear(fallas: 2);

    await viewModel.cargar();
    expect(viewModel.estado, EstadoCarga.error);

    await viewModel.cargar(forzar: true);
    expect(viewModel.estado, EstadoCarga.exito);
  });

  test('la segunda carga sale de la caché sin llamar al servicio', () async {
    crear();

    await viewModel.cargar();
    await viewModel.cargar();

    expect(service.llamadas, 1);
  });

  test('filtra por categoría y por texto', () async {
    crear();
    await viewModel.cargar();

    viewModel.elegirCategoria('Lácteos');
    expect(viewModel.productosVisibles.map((p) => p.id).toList(), ['p3', 'p6']);

    viewModel.buscar('QUESO');
    expect(viewModel.productosVisibles.single.id, 'p6');
  });

  test('las categorías salen de los productos, sin repetir', () async {
    crear();
    await viewModel.cargar();

    expect(viewModel.categorias, ['Todas', 'Almacén', 'Lácteos']);
  });
}
