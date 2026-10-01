import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshmarket_app/main.dart';

void main() {
  testWidgets('Agregar un producto actualiza el contador del carrito',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());

    expect(find.text('FreshMarket'), findsOneWidget);
    // Con el carrito vacío no aparece el botón "Ver pedido".
    expect(find.textContaining('Ver pedido'), findsNothing);

    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ver pedido · 1'), findsOneWidget);
  });

  testWidgets('El filtro por categoría muestra solo esa categoría',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());

    await tester.tap(find.widgetWithText(ChoiceChip, 'Lácteos'));
    await tester.pumpAndSettle();

    expect(find.text('Leche entera 1L'), findsOneWidget);
    expect(find.text('Yerba mate 1kg'), findsNothing);
  });

  testWidgets('Flujo completo: agregar, pagar y ver el seguimiento',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());

    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ver pedido'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a pagar'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Pagar \$'));
    await tester.pump(); // arranca el "procesando pago"
    expect(find.text('Procesando pago...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Pedido #1001'), findsOneWidget);

    // El Timer avanza una etapa cada 3 segundos hasta "Entregado".
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpAndSettle();
    expect(find.text('Hacer otro pedido'), findsOneWidget);

    await tester.tap(find.text('Hacer otro pedido'));
    await tester.pumpAndSettle();
    // Volvimos al catálogo con el carrito vacío.
    expect(find.text('El almacén de Don Ceferino'), findsOneWidget);
    expect(find.textContaining('Ver pedido'), findsNothing);
  });
}
