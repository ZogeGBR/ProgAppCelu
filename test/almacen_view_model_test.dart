import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/ui/almacen/view_models/almacen_view_model.dart';
import 'package:freshmarket_app/ui/catalogo/view_models/catalogo_view_model.dart';
import 'package:freshmarket_app/ui/core/estado_carga.dart';

import 'fakes.dart';

void main() {
  late CatalogoServiceFalso service;
  late CatalogoViewModel catalogo;
  late AlmacenViewModel viewModel;

  setUp(() async {
    service = CatalogoServiceFalso();
    final repositorio = CatalogoRepository(service: service);
    catalogo = CatalogoViewModel(repositorio: repositorio);
    // No se conocen: los dos observan al mismo repositorio.
    viewModel = AlmacenViewModel(repositorio: repositorio);
    await catalogo.cargar();
    await viewModel.cargar();
  });

  tearDown(() {
    viewModel.dispose();
    catalogo.dispose();
  });

  // El catálogo se recarga en segundo plano: hay que dejarlo terminar.
  Future<void> esperarCatalogo() => Future<void>.delayed(Duration.zero);

  test('carga los productos', () {
    expect(viewModel.estado, EstadoCarga.exito);
    expect(viewModel.productos.length, 3);
  });

  test('cambiar el precio llega también a la pantalla de comprar', () async {
    final yerbaCargada = viewModel.productos.first;

    final ok = await viewModel.cambiarPrecio(yerbaCargada, '\$4.200');

    expect(ok, isTrue);
    expect(viewModel.productos.first.precio, 4200);
    await esperarCatalogo();
    expect(catalogo.productosVisibles.first.precio, 4200);
  });

  test('un precio inválido no se guarda', () async {
    final yerbaCargada = viewModel.productos.first;

    expect(await viewModel.cambiarPrecio(yerbaCargada, 'gratis'), isFalse);
    expect(await viewModel.cambiarPrecio(yerbaCargada, '0'), isFalse);
    expect(viewModel.productos.first.precio, 3800);
  });

  test('marcar "no hay" se ve al comprar', () async {
    await viewModel.cambiarDisponible(viewModel.productos.first, false);

    expect(viewModel.productos.first.disponible, isFalse);
    await esperarCatalogo();
    expect(catalogo.productosVisibles.first.disponible, isFalse);
  });

  test('borrar lo saca de las dos pantallas', () async {
    await viewModel.eliminar(viewModel.productos.first);

    expect(viewModel.productos.map((p) => p.id), isNot(contains('p2')));
    await esperarCatalogo();
    expect(catalogo.productosVisibles.map((p) => p.id), isNot(contains('p2')));
  });

  test('si no se puede guardar, avisa y no cambia nada', () async {
    service.fallaAlGuardar = true;

    await viewModel.cambiarPrecio(viewModel.productos.first, '9999');

    expect(viewModel.fallo, isTrue);
    expect(viewModel.productos.first.precio, 3800);
  });
}
