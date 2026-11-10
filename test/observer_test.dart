import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/catalogo_repository.dart';
import 'package:freshmarket_app/data/repositories/etiquetado_repository.dart';
import 'package:freshmarket_app/data/repositories/pago_repository.dart';
import 'package:freshmarket_app/data/repositories/reparto_repository.dart';
import 'package:freshmarket_app/data/repositories/seguimiento_repository.dart';
import 'package:freshmarket_app/data/repositories/sesion_repository.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/almacen/view_models/almacen_view_model.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/catalogo/view_models/catalogo_view_model.dart';
import 'package:freshmarket_app/ui/escaner/view_models/escaner_view_model.dart';
import 'package:freshmarket_app/ui/inicio/view_models/navegacion_view_model.dart';
import 'package:freshmarket_app/ui/pago/view_models/pago_view_model.dart';
import 'package:freshmarket_app/ui/reparto/view_models/reparto_view_model.dart';
import 'package:freshmarket_app/ui/seguimiento/view_models/seguimiento_view_model.dart';

import 'fakes.dart';

/// Pruebas del patrón Observer entre capas: un repositorio (sujeto)
/// publica un cambio y los ViewModels que lo observan se actualizan solos,
/// sin conocerse entre ellos.
void main() {
  test('cada notifyListeners() le llega a todos los que escuchan', () {
    final carrito = CarritoViewModel();
    var avisosA = 0;
    var avisosB = 0;
    void observadorA() => avisosA++;
    carrito
      ..addListener(observadorA)
      ..addListener(() => avisosB++)
      ..agregarProducto(yerba);

    expect((avisosA, avisosB), (1, 1));

    // Un observador que se da de baja no recibe más avisos.
    carrito
      ..removeListener(observadorA)
      ..agregarProducto(yerba);
    expect((avisosA, avisosB), (1, 2));
  });

  group('catálogo', () {
    late CatalogoRepository repositorio;
    late CatalogoViewModel comprar;
    late AlmacenViewModel almacen;

    setUp(() async {
      repositorio = CatalogoRepository(service: CatalogoServiceFalso());
      comprar = CatalogoViewModel(repositorio: repositorio);
      almacen = AlmacenViewModel(repositorio: repositorio);
      await comprar.cargar();
    });

    tearDown(() {
      comprar.dispose();
      almacen.dispose();
    });

    test('al cargar en "Comprar", "Mi almacén" también recibe la lista', () {
      expect(almacen.productos.length, 3);
    });

    test('un producto cargado con la foto aparece en las dos pantallas',
        () async {
      final escaner = EscanerViewModel(
        etiquetado: EtiquetadoRepository(
          camara: CamaraFalsa(foto: Uint8List.fromList([1])),
          etiquetado: EtiquetadoServiceFalso(),
        ),
        catalogo: repositorio,
      );
      addTearDown(escaner.dispose);

      await escaner.sacarFoto();
      await escaner.guardar();

      const nombre = 'Aceite de girasol 1.5L';
      expect(comprar.productosVisibles.map((p) => p.nombre), contains(nombre));
      expect(almacen.productos.map((p) => p.nombre), contains(nombre));
    });

    test('una pantalla dada de baja deja de observar', () async {
      final otro = CatalogoViewModel(repositorio: repositorio)..dispose();

      // Si siguiera suscripto, notifyListeners() de un ViewModel
      // descartado tiraría error.
      await almacen.cambiarPrecio(almacen.productos.first, '5000');

      expect(otro.productosVisibles, isEmpty);
      expect(comprar.productosVisibles.first.precio, 5000);
    });
  });

  group('pago confirmado', () {
    late PagoRepository pagos;
    late CarritoViewModel carrito;
    late SeguimientoViewModel seguimiento;

    PagoViewModel nuevoPago(List<String> respuestas) {
      pagos = PagoRepository(
        service: PagoServiceFalso(respuestas: respuestas),
        checkout: CheckoutFalso(),
        intervaloConsulta: const Duration(milliseconds: 5),
      );
      carrito = CarritoViewModel(pagos: pagos)..agregarProducto(yerba);
      seguimiento = SeguimientoViewModel(
        repositorio: SeguimientoRepository(service: SeguimientoServiceFalso()),
        pagos: pagos,
      );
      addTearDown(carrito.dispose);
      addTearDown(seguimiento.dispose);
      return PagoViewModel(repositorio: pagos, armarPedido: carrito.armarPedido)
        ..elegirMetodo(MetodoPago.debito)
        ..cambiarDireccion('Belgrano 55');
    }

    Future<void> esperar(PagoViewModel pago) async {
      while (pago.estaOcupado) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('aprobado: el carrito se vacía y "Mi pedido" empieza a seguirlo',
        () async {
      final pago = nuevoPago(['pendiente', 'aprobado']);
      addTearDown(pago.dispose);

      await pago.pagar();
      expect(carrito.estaVacio, isFalse, reason: 'todavía no se aprobó');
      await esperar(pago);

      expect(carrito.estaVacio, isTrue);
      expect(seguimiento.hayPedido, isTrue);
      expect(seguimiento.pedido?.id, pago.pedido?.id);
    });

    test('rechazado: nadie se entera y el carrito queda como estaba', () async {
      final pago = nuevoPago(['rechazado']);
      addTearDown(pago.dispose);

      await pago.pagar();
      await esperar(pago);

      expect(carrito.cantidadDe(yerba), 1);
      expect(seguimiento.hayPedido, isFalse);
    });
  });

  group('sesión', () {
    late SesionRepository sesion;
    late NavegacionViewModel navegacion;
    late RepartoViewModel reparto;
    late AlmacenViewModel almacen;
    late UbicacionFalsa gps;

    setUp(() {
      sesion = SesionRepository(service: SesionServiceFalso());
      gps = UbicacionFalsa();
      navegacion = NavegacionViewModel(sesion: sesion);
      reparto = RepartoViewModel(
        repositorio: RepartoRepository(
          service: RepartoServiceFalso(),
          ubicacion: gps,
        ),
        sesion: sesion,
      );
      almacen = AlmacenViewModel(
        repositorio: CatalogoRepository(service: CatalogoServiceFalso()),
        sesion: sesion,
      );
    });

    tearDown(() {
      navegacion.dispose();
      reparto.dispose();
      almacen.dispose();
    });

    test('entra el dueño: se abre "Mi almacén" y carga los productos',
        () async {
      await sesion.ingresar('ceferino@x.com', 'clave-dueno');
      await Future<void>.delayed(Duration.zero);

      expect(navegacion.actual, Seccion.almacen);
      expect(almacen.productos, isNotEmpty);
    });

    test('entra el repartidor: se abre "Repartir" con sus pedidos', () async {
      await sesion.ingresar('tobias@x.com', 'clave-reparto');
      await Future<void>.delayed(Duration.zero);

      expect(navegacion.actual, Seccion.repartir);
      expect(reparto.paso, PasoReparto.eligiendo);
    });

    test('al salir se apaga el GPS y se vuelve a "Comprar"', () async {
      await sesion.ingresar('tobias@x.com', 'clave-reparto');
      await Future<void>.delayed(Duration.zero);
      await reparto.empezar(reparto.pedidos.first);
      expect(gps.hayQuienEscuche, isTrue);

      sesion.salir();
      await Future<void>.delayed(Duration.zero);

      expect(gps.hayQuienEscuche, isFalse);
      expect(reparto.actual, isNull);
      expect(navegacion.actual, Seccion.comprar);
    });
  });
}
