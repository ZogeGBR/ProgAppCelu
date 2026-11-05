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

    await tester.tap(find.text('Tarjeta de débito'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Pagar \$'));
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
}
