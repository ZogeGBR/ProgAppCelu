import 'package:flutter/material.dart';

import '../../../domain/models/item_carrito.dart';
import '../../almacen/view_models/almacen_view_model.dart';
import '../../almacen/widgets/almacen_screen.dart';
import '../../avisos/view_models/avisos_view_model.dart';
import '../../carrito/view_models/carrito_view_model.dart';
import '../../carrito/widgets/carrito_screen.dart';
import '../../catalogo/view_models/catalogo_view_model.dart';
import '../../catalogo/widgets/catalogo_screen.dart';
import '../../core/rutas.dart';
import '../../reparto/view_models/reparto_view_model.dart';
import '../../reparto/widgets/reparto_screen.dart';
import '../../seguimiento/view_models/historial_view_model.dart';
import '../../seguimiento/view_models/seguimiento_view_model.dart';
import '../../seguimiento/widgets/seguimiento_screen.dart';
import '../../sesion/view_models/sesion_view_model.dart';
import '../view_models/conectividad_view_model.dart';
import '../view_models/navegacion_view_model.dart';
import 'aviso_sin_internet.dart';

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
    required this.sesion,
    required this.almacen,
    required this.reparto,
    this.avisos,
    this.conectividad,
    this.historial,
    this.permiteCargaConFoto = true,
  });

  final NavegacionViewModel navegacion;
  final CatalogoViewModel catalogo;
  final CarritoViewModel carrito;
  final SeguimientoViewModel seguimiento;
  final SesionViewModel sesion;
  final AlmacenViewModel almacen;
  final RepartoViewModel reparto;
  final AvisosViewModel? avisos;
  final ConectividadViewModel? conectividad;
  final HistorialViewModel? historial;

  /// Política (ver Politicas.permiteCargaConFoto): si es false, "Mi
  /// almacén" no muestra el botón de cargar con foto.
  final bool permiteCargaConFoto;

  List<Seccion> get _secciones => [
        Seccion.comprar,
        Seccion.carrito,
        Seccion.miPedido,
        if (sesion.esDueno) Seccion.almacen,
        if (sesion.esRepartidor) Seccion.repartir,
      ];

  // Rutas con nombre: quién arma cada pantalla lo decide onGenerateRoute
  // (main.dart). Acá solo se dice A DÓNDE ir.
  void _abrirIngreso(BuildContext context) =>
      Navigator.pushNamed(context, Rutas.ingresar);

  void _abrirCargaConFoto(BuildContext context) =>
      Navigator.pushNamed(context, Rutas.cargarConFoto);

  void _abrirPago(BuildContext context) =>
      Navigator.pushNamed(context, Rutas.pago);

  // Al entrar o salir no hace falta avisarle a nadie: la barra, "Mi
  // almacén" y el reparto observan la sesión (patrón Observer).
  void _salir() => sesion.salir();

  /// "Volver a pedir": los productos de un pedido viejo, con el precio de
  /// hoy, van al carrito y se abre el carrito para revisarlo.
  void _volverAPedir(List<ItemCarrito> items) {
    carrito.agregarItems(catalogo.conPreciosDeHoy(items));
    navegacion.irA(Seccion.carrito);
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
          body: Column(
            children: [
              if (conectividad case final conectividad?)
                AvisoSinInternet(viewModel: conectividad),
              Expanded(
                child: IndexedStack(
                  index: indice < 0 ? 0 : indice,
                  children: [
                    for (final seccion in secciones)
                      _pantallaDe(seccion, context),
                  ],
                ),
              ),
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
          avisos: avisos,
          historial: historial,
          alVolverAPedir: _volverAPedir,
          alIrAComprar: () => navegacion.irA(Seccion.comprar),
        ),
      Seccion.almacen => AlmacenScreen(
          viewModel: almacen,
          alCargarConFoto: permiteCargaConFoto
              ? () => _abrirCargaConFoto(context)
              : null,
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
