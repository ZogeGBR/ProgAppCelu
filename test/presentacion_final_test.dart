// Pantallas de lo que se agregó para la presentación final: políticas,
// sin internet, gestos, grilla adaptativa e historial con "Volver a pedir".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/config/dependencias.dart';
import 'package:freshmarket_app/data/services/carrito_local_service.dart';
import 'package:freshmarket_app/data/services/conectividad_service.dart';
import 'package:freshmarket_app/data/services/historial_dao.dart';
import 'package:freshmarket_app/data/services/pedido_local_service.dart';
import 'package:freshmarket_app/data/services/recordatorio_service.dart';
import 'package:freshmarket_app/domain/models/funciones.dart';
import 'package:freshmarket_app/domain/models/item_carrito.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/domain/models/pedido_anterior.dart';
import 'package:freshmarket_app/domain/politicas/politicas.dart';
import 'package:freshmarket_app/main.dart';

import 'fakes.dart';

void main() {
  late ConectividadServiceSimulado red;
  late HistorialServiceMemoria historial;

  Future<void> abrirApp(WidgetTester tester, {Politicas? politicas}) async {
    red = ConectividadServiceSimulado();
    final dependencias = Dependencias.simuladas(
      catalogoService: CatalogoServiceFalso(),
      seguimientoService: SeguimientoServiceFalso(),
      camara: CamaraFalsa(),
      pagoService: PagoServiceFalso(),
      carritoLocalService: CarritoLocalServiceMemoria(),
      pedidoLocalService: PedidoLocalServiceMemoria(),
      geocodificacionService: GeocodificacionFalsa(),
      ubicacionService: UbicacionFalsa(),
      notificacionLocal: NotificacionLocalFalsa(),
      conectividadService: red,
      recordatorioService: RecordatorioServiceSimulado(),
      historialService: historial,
    );
    await tester.pumpWidget(
      FreshMarketApp(dependencias: dependencias, politicas: politicas),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => historial = HistorialServiceMemoria());

  testWidgets('sin internet aparece el aviso y se va al volver la red',
      (tester) async {
    await abrirApp(tester);
    expect(find.textContaining('Sin internet'), findsNothing);

    red.cambiar(hayRed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin internet'), findsOneWidget);

    red.cambiar(hayRed: true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin internet'), findsNothing);
  });

  testWidgets('tocar un producto abre su detalle y desde ahí se agrega',
      (tester) async {
    await abrirApp(tester);

    await tester.longPress(find.text('Yerba mate 1kg'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar al carrito'), findsOneWidget);

    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ver mi carrito · 1'), findsOneWidget);
  });

  testWidgets('deslizar un renglón del carrito lo saca y se puede deshacer',
      (tester) async {
    await abrirApp(tester);
    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi carrito'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible).first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Tu carrito está vacío.'), findsOneWidget);

    await tester.tap(find.text('Deshacer').first);
    await tester.pumpAndSettle();
    expect(find.text('Ir a pagar'), findsOneWidget);
  });

  testWidgets('en pantallas anchas el catálogo se muestra en grilla',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await abrirApp(tester);

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('en el celular el catálogo es una lista', (tester) async {
    await abrirApp(tester);

    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('si el servidor apaga el efectivo, no se ofrece',
      (tester) async {
    await abrirApp(
      tester,
      politicas: Politicas(funciones: const Funciones(pagoEnEfectivo: false)),
    );
    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ver mi carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a pagar'));
    await tester.pumpAndSettle();

    // El campo de texto tiene su propio Scrollable: se usa el de la lista.
    await tester.scrollUntilVisible(
      find.text('Dinero en Mercado Pago'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Efectivo al recibir'), findsNothing);
  });

  testWidgets('"Volver a pedir" pone el pedido anterior en el carrito',
      (tester) async {
    await historial.guardar(
      PedidoAnterior(
        id: 'viejo-1',
        numero: 1001,
        // Reciente: el historial borra solo lo de más de 90 días.
        fecha: DateTime.now().subtract(const Duration(days: 3)),
        metodoPago: MetodoPago.debito,
        items: const [ItemCarrito(producto: yerba, cantidad: 2)],
      ).toMap(),
    );
    await abrirApp(tester);

    await tester.tap(find.text('Mi pedido'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pedido #1001'), findsOneWidget);

    await tester.tap(find.text('Volver a pedir'));
    await tester.pumpAndSettle();

    // Se abre el carrito con la yerba (2 unidades, precio de hoy).
    expect(find.text('Yerba mate 1kg'), findsWidgets);
    expect(find.text('Ir a pagar'), findsOneWidget);
  });
}
