import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/config/dependencias.dart';
import 'package:freshmarket_app/data/services/carrito_local_service.dart';
import 'package:freshmarket_app/data/services/conectividad_service.dart';
import 'package:freshmarket_app/data/services/historial_dao.dart';
import 'package:freshmarket_app/data/services/pedido_local_service.dart';
import 'package:freshmarket_app/data/services/recordatorio_service.dart';
import 'package:freshmarket_app/data/services/sesion_service.dart';
import 'package:freshmarket_app/domain/models/aviso.dart';
import 'package:freshmarket_app/main.dart';

import 'fakes.dart';

void main() {
  late SeguimientoServiceFalso seguimiento;

  Future<void> abrirApp(
    WidgetTester tester, {
    PushFalso? push,
    NotificacionLocalFalsa? local,
  }) async {
    seguimiento = SeguimientoServiceFalso();
    final dependencias = Dependencias.simuladas(
      catalogoService: CatalogoServiceFalso(),
      seguimientoService: seguimiento,
      camara: CamaraFalsa(),
      pagoService: PagoServiceFalso(),
      carritoLocalService: CarritoLocalServiceMemoria(),
      pedidoLocalService: PedidoLocalServiceMemoria(),
      geocodificacionService: GeocodificacionFalsa(),
      ubicacionService: UbicacionFalsa(),
      // Sin el plugin real: en las pruebas no hay barra de notificaciones.
      notificacionLocal: local ?? NotificacionLocalFalsa(),
      push: push,
      // Sin plugins en las pruebas: red, recordatorios y SQLite falsos.
      conectividadService: ConectividadServiceSimulado(),
      recordatorioService: RecordatorioServiceSimulado(),
      historialService: HistorialServiceMemoria(),
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

  group('ingreso con email y contraseña', () {
    const emailDueno = SesionServiceSimulado.emailDueno;
    const claveDemo = SesionServiceSimulado.claveInicial;

    Finder campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

    Future<void> abrirIngreso(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Soy del almacén'));
      await tester.pumpAndSettle();
    }

    Future<void> ingresarCon(
      WidgetTester tester,
      String email,
      String clave,
    ) async {
      await abrirIngreso(tester);
      await tester.enterText(campo('Email'), email);
      await tester.enterText(campo('Contraseña'), clave);
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
    }

    bool claveOculta(WidgetTester tester) =>
        tester.widget<TextField>(campo('Contraseña')).obscureText;

    testWidgets('un cliente no ve las secciones del almacén', (tester) async {
      await abrirApp(tester);

      expect(find.text('Mi almacén'), findsNothing);
      expect(find.text('Repartir'), findsNothing);
    });

    testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
      await abrirApp(tester);
      await abrirIngreso(tester);
      await tester.enterText(campo('Contraseña'), 'secreta');

      expect(claveOculta(tester), isTrue);

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(claveOculta(tester), isFalse);
      expect(find.text('secreta'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(claveOculta(tester), isTrue);
    });

    testWidgets('una contraseña mala no entra y avisa', (tester) async {
      await abrirApp(tester);

      await ingresarCon(tester, emailDueno, 'cualquiera');

      expect(
        find.text('El email o la contraseña no son correctos.'),
        findsOneWidget,
      );
    });

    testWidgets('el dueño ve "Mi almacén" y al salir desaparece',
        (tester) async {
      await abrirApp(tester);

      await ingresarCon(tester, emailDueno, claveDemo);
      expect(find.text('Cargar producto con una foto'), findsOneWidget);

      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Mi almacén'), findsNothing);
      expect(find.byTooltip('Soy del almacén'), findsOneWidget);
    });

    testWidgets('el repartidor ve sus pedidos', (tester) async {
      await abrirApp(tester);

      await ingresarCon(
          tester, SesionServiceSimulado.emailRepartidor, claveDemo);

      expect(find.text('Salir a repartir'), findsOneWidget);
    });

    testWidgets('recuperar la contraseña y entrar con la nueva',
        (tester) async {
      await abrirApp(tester);
      await abrirIngreso(tester);
      await tester.enterText(campo('Email'), emailDueno);

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      // El email ya escrito pasa solo a la pantalla de recuperación.
      expect(find.text(emailDueno), findsOneWidget);

      await tester.tap(find.text('Mandarme el código'));
      await tester.pumpAndSettle();
      await tester.enterText(
        campo('Código'),
        SesionServiceSimulado.codigoDemo,
      );
      await tester.enterText(campo('Contraseña nueva'), 'clave-nueva-1');
      await tester.enterText(
        campo('Repetí la contraseña nueva'),
        'clave-nueva-1',
      );
      await tester.ensureVisible(find.text('Guardar contraseña nueva'));
      await tester.tap(find.text('Guardar contraseña nueva'));
      await tester.pumpAndSettle();
      expect(find.text('¡Listo! Tu contraseña cambió.'), findsOneWidget);

      await tester.tap(find.text('Volver a ingresar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Listo. Ya podés ingresar con tu contraseña nueva.'),
        findsOneWidget,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.enterText(campo('Contraseña'), 'clave-nueva-1');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Cargar producto con una foto'), findsOneWidget);
    });
  });

  group('notificaciones', () {
    const enCamino = Aviso(
      titulo: 'Tu pedido #1001 está en camino',
      cuerpo: 'El repartidor ya salió.',
      pedidoId: 'p-1',
    );

    testWidgets('un aviso con la app abierta se muestra en la barra',
        (tester) async {
      final push = PushFalso();
      final local = NotificacionLocalFalsa();
      await abrirApp(tester, push: push, local: local);

      push.enviar(enCamino);
      await tester.pumpAndSettle();

      expect(local.mostradas.single.titulo, enCamino.titulo);
    });

    testWidgets(
        'tocar el aviso desde el pago cierra el pago y abre "Mi pedido"',
        (tester) async {
      final push = PushFalso();
      await abrirApp(tester, push: push);
      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Ver mi carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir a pagar'));
      await tester.pumpAndSettle();
      expect(find.text('Calle y número'), findsOneWidget);

      push.tocar(enCamino);
      await tester.pumpAndSettle();

      // Se cerró el pago y se ve "Mi pedido" (todavía sin pedido).
      expect(find.text('Calle y número'), findsNothing);
      expect(find.text('Todavía no hiciste ningún pedido.'), findsOneWidget);
    });
  });
}
