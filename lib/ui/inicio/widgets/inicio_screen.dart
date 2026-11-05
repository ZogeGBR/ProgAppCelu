import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/pago_repository.dart';
import '../../almacen/view_models/almacen_view_model.dart';
import '../../almacen/widgets/almacen_screen.dart';
import '../../carrito/view_models/carrito_view_model.dart';
import '../../carrito/widgets/carrito_screen.dart';
import '../../catalogo/view_models/catalogo_view_model.dart';
import '../../catalogo/widgets/catalogo_screen.dart';
import '../../escaner/view_models/escaner_view_model.dart';
import '../../escaner/widgets/escaner_screen.dart';
import '../../pago/view_models/pago_view_model.dart';
import '../../pago/widgets/pago_screen.dart';
import '../../reparto/view_models/reparto_view_model.dart';
import '../../reparto/widgets/reparto_screen.dart';
import '../../seguimiento/view_models/seguimiento_view_model.dart';
import '../../seguimiento/widgets/seguimiento_screen.dart';
import '../../sesion/view_models/sesion_view_model.dart';
import '../../sesion/widgets/ingresar_screen.dart';
import '../view_models/navegacion_view_model.dart';

/// Pantalla principal con la barra de abajo.
///
/// Toda la app se maneja con 3 botones grandes siempre visibles
/// (Comprar, Mi carrito, Mi pedido), más "Mi almacén" para el dueño o
/// "Repartir" para el repartidor, una vez que ingresan con su clave.
/// No hay menús escondidos: cada cosa está a un toque.
class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.navegacion,
    required this.catalogo,
    required this.carrito,
    required this.seguimiento,
    required this.escaner,
    required this.sesion,
    required this.almacen,
    required this.reparto,
    required this.pagoRepositorio,
    this.pistaClaves,
  });

  final NavegacionViewModel navegacion;
  final CatalogoViewModel catalogo;
  final CarritoViewModel carrito;
  final SeguimientoViewModel seguimiento;
  final EscanerViewModel escaner;
  final SesionViewModel sesion;
  final AlmacenViewModel almacen;
  final RepartoViewModel reparto;
  final PagoRepository pagoRepositorio;
  final String? pistaClaves;

  List<Seccion> get _secciones => [
        Seccion.comprar,
        Seccion.carrito,
        Seccion.miPedido,
        if (sesion.esDueno) Seccion.almacen,
        if (sesion.esRepartidor) Seccion.repartir,
      ];

  void _abrirIngreso(BuildContext context) {
    final pantalla = IngresarScreen(
      viewModel: sesion,
      pista: pistaClaves,
      alIngresar: _alIngresar,
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _alIngresar() {
    if (sesion.esDueno) {
      unawaited(almacen.cargar(forzar: true));
      navegacion.irA(Seccion.almacen);
    } else {
      unawaited(reparto.cargar());
      navegacion.irA(Seccion.repartir);
    }
  }

  void _salir() {
    reparto.detener();
    sesion.salir();
    navegacion.irA(Seccion.comprar);
  }

  void _abrirCargaConFoto(BuildContext context) {
    final pantalla = EscanerScreen(viewModel: escaner);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _abrirPago(BuildContext context) {
    final pantalla = PagoScreen(
      viewModel: PagoViewModel(
        repositorio: pagoRepositorio,
        armarPedido: carrito.armarPedido,
        alAprobar: (pedido) {
          carrito.vaciarCarrito();
          seguimiento.seguir(pedido);
        },
      ),
      items: carrito.items,
      total: carrito.total,
      alVerPedido: () => navegacion.irA(Seccion.miPedido),
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([navegacion, carrito, seguimiento, sesion]),
      builder: (context, _) {
        // Cambian según quién haya ingresado.
        final secciones = _secciones;
        final indice = secciones.indexOf(navegacion.actual);

        return Scaffold(
          // IndexedStack conserva cada sección (búsqueda, scroll) al
          // cambiar de pestaña.
          body: IndexedStack(
            index: indice < 0 ? 0 : indice,
            children: [
              for (final seccion in secciones) _pantallaDe(seccion, context),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: indice < 0 ? 0 : indice,
            onDestinationSelected: (i) => navegacion.irA(secciones[i]),
            destinations: [
              for (final seccion in secciones) _destinoDe(seccion),
            ],
          ),
        );
      },
    );
  }

  Widget _pantallaDe(Seccion seccion, BuildContext context) {
    return switch (seccion) {
      Seccion.comprar => CatalogoScreen(
          viewModel: catalogo,
          carrito: carrito,
          alVerCarrito: () => navegacion.irA(Seccion.carrito),
          alIngresar: sesion.haySesion ? null : () => _abrirIngreso(context),
        ),
      Seccion.carrito => CarritoScreen(
          carrito: carrito,
          alIrAPagar: () => _abrirPago(context),
          alIrAComprar: () => navegacion.irA(Seccion.comprar),
        ),
      Seccion.miPedido => SeguimientoScreen(
          viewModel: seguimiento,
          alIrAComprar: () => navegacion.irA(Seccion.comprar),
        ),
      Seccion.almacen => AlmacenScreen(
          viewModel: almacen,
          alCargarConFoto: () => _abrirCargaConFoto(context),
          alSalir: _salir,
        ),
      Seccion.repartir => RepartoScreen(viewModel: reparto, alSalir: _salir),
    };
  }

  NavigationDestination _destinoDe(Seccion seccion) {
    return switch (seccion) {
      Seccion.comprar => const NavigationDestination(
          icon: Icon(Icons.storefront_outlined, size: 30),
          selectedIcon: Icon(Icons.storefront, size: 30),
          label: 'Comprar',
        ),
      Seccion.carrito => NavigationDestination(
          icon: Badge(
            isLabelVisible: !carrito.estaVacio,
            label: Text('${carrito.cantidadTotal}'),
            child: const Icon(Icons.shopping_cart_outlined, size: 30),
          ),
          selectedIcon: Badge(
            isLabelVisible: !carrito.estaVacio,
            label: Text('${carrito.cantidadTotal}'),
            child: const Icon(Icons.shopping_cart, size: 30),
          ),
          label: 'Mi carrito',
        ),
      Seccion.miPedido => NavigationDestination(
          icon: Badge(
            isLabelVisible: seguimiento.hayPedido && !seguimiento.entregado,
            child: const Icon(Icons.pedal_bike, size: 30),
          ),
          label: 'Mi pedido',
        ),
      Seccion.almacen => const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined, size: 30),
          selectedIcon: Icon(Icons.inventory_2, size: 30),
          label: 'Mi almacén',
        ),
      Seccion.repartir => const NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined, size: 30),
          selectedIcon: Icon(Icons.delivery_dining, size: 30),
          label: 'Repartir',
        ),
    };
  }
}
