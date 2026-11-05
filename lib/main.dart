import 'dart:async';

import 'package:flutter/material.dart';

import 'config/dependencias.dart';
import 'ui/carrito/view_models/carrito_view_model.dart';
import 'ui/catalogo/view_models/catalogo_view_model.dart';
import 'ui/core/tema.dart';
import 'ui/escaner/view_models/escaner_view_model.dart';
import 'ui/inicio/view_models/navegacion_view_model.dart';
import 'ui/inicio/widgets/inicio_screen.dart';
import 'ui/seguimiento/view_models/seguimiento_view_model.dart';

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

  @override
  void initState() {
    super.initState();
    final dependencias = widget.dependencias;
    _navegacion = NavegacionViewModel();
    _carrito = CarritoViewModel();
    _catalogo = CatalogoViewModel(repositorio: dependencias.catalogo);
    _seguimiento = SeguimientoViewModel(repositorio: dependencias.seguimiento);
    _escaner = EscanerViewModel(
      etiquetado: dependencias.etiquetado,
      catalogo: dependencias.catalogo,
      alGuardar: _catalogo.cargar,
    );
    unawaited(_catalogo.cargar());
  }

  @override
  void dispose() {
    _navegacion.dispose();
    _carrito.dispose();
    _catalogo.dispose();
    _seguimiento.dispose();
    _escaner.dispose();
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
        pagoRepositorio: widget.dependencias.pago,
        mostrarModoDueno: widget.dependencias.mostrarModoDueno,
      ),
    );
  }
}
