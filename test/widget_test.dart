import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/config/dependencias.dart';
import 'package:freshmarket_app/main.dart';

import 'fakes.dart';

void main() {
  late SeguimientoServiceFalso seguimiento;

  Future<void> abrirApp(WidgetTester tester) async {
    seguimiento = SeguimientoServiceFalso();
    final dependencias = Dependencias.simuladas(
      catalogoService: CatalogoServiceFalso(),
      seguimientoService: seguimiento,
      camara: CamaraFalsa(),
      pagoService: PagoServiceFalso(),
    );
    await tester.pumpWidget(FreshMarketApp(dependencias: dependencias));
    await tester.pumpAndSettle();
  }

  // El campo de texto tiene su propio Scrollable: hay que pedir el de la lista.
  Finder listaDePago() => find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('la barra de abajo tiene las secciones principales',
      (tester) async {
    await abrirApp(tester);

    expect(find.text('Comprar'), findsOneWidget);
    expect(find.text('Mi carrito'), findsOneWidget);
    expect(find.text('Mi pedido'), findsOneWidget);
  });

  testWidgets('agregar un producto muestra el botón del carrito',
      (tester) async {
    await abrirApp(tester);
    expect(find.textContaining('Ver mi carrito'), findsNothing);

    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ver mi carrito · 1'), findsOneWidget);
  });

  testWidgets('el filtro por categoría muestra solo esa categoría',
      (tester) async {
    await abrirApp(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Lácteos'));
    await tester.pumpAndSettle();

    expect(find.text('Leche entera 1L'), findsOneWidget);
    expect(find.text('Yerba mate 1kg'), findsNothing);
  });

  testWidgets('flujo completo: agregar, pagar y ver el seguimiento',
      (tester) async {
    await abrirApp(tester);

    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ver mi carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a pagar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calle y número'),
      'San Martín 1234',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Tarjeta de débito'),
      200,
      scrollable: listaDePago(),
    );
    await tester.tap(find.text('Tarjeta de débito'));
    await tester.pumpAndSettle();
    // ListView construye a demanda: hay que desplazar hasta que el botón exista.
    await tester.scrollUntilVisible(
      find.textContaining('Pagar \$'),
      200,
      scrollable: listaDePago(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pagar \$'));
    await tester.pump(); // Abre Mercado Pago (simulado).
    await tester.pump(); // Empieza a esperar la confirmación.
    expect(find.textContaining('Esperando la confirmación'), findsOneWidget);

    // La primera consulta del estado llega después de 1 segundo.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('¡Listo! Tu pago fue aprobado.'), findsOneWidget);

    await tester.tap(find.text('Ver mi pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido #1001'), findsOneWidget);
    expect(find.text('Pedido recibido'), findsWidgets);

    seguimiento.emitir({'estado': 'entregado'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hacer otro pedido'));
    await tester.pumpAndSettle();

    // Volvimos a "Comprar" con el carrito vacío.
    expect(find.text('El almacén de Don Ceferino'), findsOneWidget);
    expect(find.textContaining('Ver mi carrito'), findsNothing);
  });

  group('ingreso con clave', () {
    Future<void> ingresarCon(WidgetTester tester, String clave) async {
      await tester.tap(find.byTooltip('Soy del almacén'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), clave);
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
    }

    testWidgets('un cliente no ve las secciones del almacén', (tester) async {
      await abrirApp(tester);

      expect(find.text('Mi almacén'), findsNothing);
      expect(find.text('Repartir'), findsNothing);
    });

    testWidgets('una clave mala no entra y avisa', (tester) async {
      await abrirApp(tester);

      await ingresarCon(tester, 'cualquiera');

      expect(find.text('Esa clave no es correcta.'), findsOneWidget);
    });

    testWidgets('el dueño ve "Mi almacén" y al salir desaparece',
        (tester) async {
      await abrirApp(tester);

      await ingresarCon(tester, 'dueno');
      expect(find.text('Cargar producto con una foto'), findsOneWidget);

      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Mi almacén'), findsNothing);
      expect(find.byTooltip('Soy del almacén'), findsOneWidget);
    });

    testWidgets('el repartidor ve sus pedidos', (tester) async {
      await abrirApp(tester);

      await ingresarCon(tester, 'repartidor');

      expect(find.text('Salir a repartir'), findsOneWidget);
    });
  });
}
