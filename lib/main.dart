import 'dart:async';

import 'package:flutter/material.dart';

import 'config/dependencias.dart';
import 'ui/almacen/view_models/almacen_view_model.dart';
import 'ui/carrito/view_models/carrito_view_model.dart';
import 'ui/catalogo/view_models/catalogo_view_model.dart';
import 'ui/core/tema.dart';
import 'ui/escaner/view_models/escaner_view_model.dart';
import 'ui/inicio/view_models/navegacion_view_model.dart';
import 'ui/inicio/widgets/inicio_screen.dart';
import 'ui/reparto/view_models/reparto_view_model.dart';
import 'ui/seguimiento/view_models/seguimiento_view_model.dart';
import 'ui/sesion/view_models/sesion_view_model.dart';

void main() {
  runApp(FreshMarketApp(dependencias: Dependencias.desdeConfiguracion()));
}

/// Widget raíz. Crea los ViewModels UNA sola vez (en initState) y los
/// descarta al cerrar la app.
class FreshMarketApp extends StatefulWidget {
  const FreshMarketApp({super.key, required this.dependencias});

  final Dependencias dependencias;

  @override
  State<FreshMarketApp> createState() => _FreshMarketAppState();
}

class _FreshMarketAppState extends State<FreshMarketApp> {
  late final NavegacionViewModel _navegacion;
  late final CarritoViewModel _carrito;
  late final CatalogoViewModel _catalogo;
  late final SeguimientoViewModel _seguimiento;
  late final EscanerViewModel _escaner;
  late final SesionViewModel _sesion;
  late final AlmacenViewModel _almacen;
  late final RepartoViewModel _reparto;

  // Eventos del sistema: avisa cuando la app pasa a segundo plano.
  late final AppLifecycleListener _cicloDeVida;

  @override
  void initState() {
    super.initState();
    final dependencias = widget.dependencias;
    _navegacion = NavegacionViewModel();
    _carrito = CarritoViewModel(repositorio: dependencias.carrito);
    _catalogo = CatalogoViewModel(repositorio: dependencias.catalogo);
    _seguimiento = SeguimientoViewModel(repositorio: dependencias.seguimiento);
    _sesion = SesionViewModel(repositorio: dependencias.sesion);
    _almacen = AlmacenViewModel(
      repositorio: dependencias.catalogo,
      alCambiarCatalogo: _catalogo.cargar,
    );
    _reparto = RepartoViewModel(repositorio: dependencias.reparto);
    _escaner = EscanerViewModel(
      etiquetado: dependencias.etiquetado,
      catalogo: dependencias.catalogo,
      alGuardar: () {
        unawaited(_catalogo.cargar());
        unawaited(_almacen.cargar());
      },
    );
    unawaited(_catalogo.cargar());
    unawaited(_carrito.restaurar());

    // Cuando la persona sale de la app (o atiende una llamada), el sistema
    // puede cerrarla sin avisar: es el último momento seguro para guardar.
    _cicloDeVida = AppLifecycleListener(
      onHide: _guardarCarrito,
      onPause: _guardarCarrito,
    );
  }

  void _guardarCarrito() => unawaited(_carrito.guardar());

  @override
  void dispose() {
    _cicloDeVida.dispose();
    _navegacion.dispose();
    _carrito.dispose();
    _catalogo.dispose();
    _seguimiento.dispose();
    _escaner.dispose();
    _sesion.dispose();
    _almacen.dispose();
    _reparto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshMarket',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      home: InicioScreen(
        navegacion: _navegacion,
        catalogo: _catalogo,
        carrito: _carrito,
        seguimiento: _seguimiento,
        escaner: _escaner,
        sesion: _sesion,
        almacen: _almacen,
        reparto: _reparto,
        pagoRepositorio: widget.dependencias.pago,
        sesionRepositorio: widget.dependencias.sesion,
        ubicacionEntregaRepositorio: widget.dependencias.ubicacionEntrega,
        pistaClaves: widget.dependencias.pistaClaves,
      ),
    );
  }
}
