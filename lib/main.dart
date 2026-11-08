import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/dependencias.dart';
import 'ui/almacen/view_models/almacen_view_model.dart';
import 'ui/avisos/view_models/avisos_view_model.dart';
import 'ui/carrito/view_models/carrito_view_model.dart';
import 'ui/catalogo/view_models/catalogo_view_model.dart';
import 'ui/core/tema.dart';
import 'ui/escaner/view_models/escaner_view_model.dart';
import 'ui/inicio/view_models/navegacion_view_model.dart';
import 'ui/inicio/widgets/inicio_screen.dart';
import 'ui/reparto/view_models/reparto_view_model.dart';
import 'ui/seguimiento/view_models/seguimiento_view_model.dart';
import 'ui/sesion/view_models/sesion_view_model.dart';

Future<void> main() async {
  // Firebase usa canales de plataforma: hay que tener el motor listo antes.
  WidgetsFlutterBinding.ensureInitialized();
  final hayFirebase = await _iniciarFirebase();
  runApp(
    FreshMarketApp(
      dependencias: Dependencias.desdeConfiguracion(hayFirebase: hayFirebase),
    ),
  );
}

/// Firebase solo hace falta para los push del backend real. Si no está
/// configurado (falta android/app/google-services.json) o no hay Google
/// Play, la app arranca igual, sin push.
Future<bool> _iniciarFirebase() async {
  if (!AppConfig.usaBackend) return false;
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    return true;
  } on Exception catch (error) {
    debugPrint('Sin Firebase (no habrá notificaciones push): $error');
    return false;
  }
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
  late final AvisosViewModel _avisos;

  // Eventos del sistema: avisa cuando la app pasa a segundo plano.
  late final AppLifecycleListener _cicloDeVida;

  // Para cerrar pantallas desde afuera de un BuildContext (al tocar una
  // notificación).
  final _navegador = GlobalKey<NavigatorState>();
  late final StreamSubscription<Seccion> _suscripcionAvisos;

  @override
  void initState() {
    super.initState();
    final dependencias = widget.dependencias;
    // Los ViewModels no se conocen entre sí: cada uno observa a los
    // repositorios que le interesan (patrón Observer). Por ejemplo, al
    // aprobarse un pago, el PagoRepository lo publica y el carrito se vacía
    // y "Mi pedido" empieza a seguirlo, sin que nadie los llame.
    _navegacion = NavegacionViewModel(
      sesion: dependencias.sesion,
      notificaciones: dependencias.notificaciones,
    );
    _carrito = CarritoViewModel(
      repositorio: dependencias.carrito,
      pagos: dependencias.pago,
    );
    _catalogo = CatalogoViewModel(repositorio: dependencias.catalogo);
    _seguimiento = SeguimientoViewModel(
      repositorio: dependencias.seguimiento,
      pagos: dependencias.pago,
    );
    _sesion = SesionViewModel(repositorio: dependencias.sesion);
    _almacen = AlmacenViewModel(
      repositorio: dependencias.catalogo,
      sesion: dependencias.sesion,
    );
    _reparto = RepartoViewModel(
      repositorio: dependencias.reparto,
      sesion: dependencias.sesion,
      notificaciones: dependencias.notificaciones,
    );
    _avisos = AvisosViewModel(
      repositorio: dependencias.notificaciones,
      pagos: dependencias.pago,
      sesion: dependencias.sesion,
    );
    _escaner = EscanerViewModel(
      etiquetado: dependencias.etiquetado,
      catalogo: dependencias.catalogo,
    );
    unawaited(_catalogo.cargar());
    unawaited(_carrito.restaurar());
    // Si la app se cerró con un pedido en viaje, "Mi pedido" lo retoma.
    unawaited(_seguimiento.restaurar());
    // Al tocar una notificación, la barra cambia de sección; acá se cierra
    // lo que haya encima para que esa sección se vea.
    _suscripcionAvisos =
        _navegacion.abiertasPorAviso.listen((_) => _volverAlInicio());
    // Al final: los que observan los avisos ya están suscriptos, así no se
    // pierden el aviso que abrió la app.
    unawaited(_avisos.iniciar());

    // Cuando la persona sale de la app (o atiende una llamada), el sistema
    // puede cerrarla sin avisar: es el último momento seguro para guardar.
    _cicloDeVida = AppLifecycleListener(
      onHide: _guardarCarrito,
      onPause: _guardarCarrito,
    );
  }

  void _guardarCarrito() => unawaited(_carrito.guardar());

  /// Cierra las pantallas abiertas encima de la principal. Se detiene en una
  /// que no deje salir (el pago mientras se procesa, con PopScope): cortar
  /// un pago a la mitad por tocar un aviso sería peor que no navegar.
  void _volverAlInicio() {
    _navegador.currentState?.popUntil(
      (ruta) =>
          ruta.isFirst || ruta.popDisposition == RoutePopDisposition.doNotPop,
    );
  }

  @override
  void dispose() {
    unawaited(_suscripcionAvisos.cancel());
    _cicloDeVida.dispose();
    _navegacion.dispose();
    _carrito.dispose();
    _catalogo.dispose();
    _seguimiento.dispose();
    _escaner.dispose();
    _sesion.dispose();
    _almacen.dispose();
    _reparto.dispose();
    _avisos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navegador,
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
        avisos: _avisos,
        pagoRepositorio: widget.dependencias.pago,
        sesionRepositorio: widget.dependencias.sesion,
        ubicacionEntregaRepositorio: widget.dependencias.ubicacionEntrega,
        pistaClaves: widget.dependencias.pistaClaves,
      ),
    );
  }
}
