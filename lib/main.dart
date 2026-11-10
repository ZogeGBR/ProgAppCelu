import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'config/dependencias.dart';
import 'data/services/push_service.dart';
import 'domain/politicas/politicas.dart';
import 'ui/almacen/view_models/almacen_view_model.dart';
import 'ui/avisos/view_models/avisos_view_model.dart';
import 'ui/carrito/view_models/carrito_view_model.dart';
import 'ui/catalogo/view_models/catalogo_view_model.dart';
import 'ui/core/rutas.dart';
import 'ui/core/tema.dart';
import 'ui/escaner/view_models/escaner_view_model.dart';
import 'ui/escaner/widgets/escaner_screen.dart';
import 'ui/inicio/view_models/conectividad_view_model.dart';
import 'ui/inicio/view_models/navegacion_view_model.dart';
import 'ui/inicio/widgets/inicio_screen.dart';
import 'ui/pago/view_models/elegir_ubicacion_view_model.dart';
import 'ui/pago/view_models/pago_view_model.dart';
import 'ui/pago/widgets/pago_screen.dart';
import 'ui/reparto/view_models/reparto_view_model.dart';
import 'ui/seguimiento/view_models/historial_view_model.dart';
import 'ui/seguimiento/view_models/seguimiento_view_model.dart';
import 'ui/sesion/view_models/recuperar_clave_view_model.dart';
import 'ui/sesion/view_models/sesion_view_model.dart';
import 'ui/sesion/widgets/ingresar_screen.dart';

Future<void> main() async {
  // Firebase usa canales de plataforma: hay que tener el motor listo antes.
  WidgetsFlutterBinding.ensureInitialized();
  final hayFirebase = await _iniciarFirebase();
  final dependencias = Dependencias.desdeConfiguracion(hayFirebase: hayFirebase);
  // Chequeo "desde el servidor": qué funciones están prendidas. Si el
  // servidor no responde en 3 s, se sigue con todo prendido.
  final funciones = await dependencias.funciones.cargar();
  runApp(
    FreshMarketApp(
      dependencias: dependencias,
      politicas: Politicas(funciones: funciones),
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
    // Push con la app en segundo plano o cerrada: corre en otro isolate.
    FirebaseMessaging.onBackgroundMessage(manejarPushEnSegundoPlano);
    return true;
  } on Exception catch (error) {
    debugPrint('Sin Firebase (no habrá notificaciones push): $error');
    return false;
  }
}

/// Widget raíz. Crea los ViewModels UNA sola vez (en initState) y los
/// descarta al cerrar la app.
class FreshMarketApp extends StatefulWidget {
  const FreshMarketApp({
    super.key,
    required this.dependencias,
    this.politicas,
  });

  final Dependencias dependencias;

  /// Capacidades y políticas. Sin pasarla, se usa la del dispositivo con
  /// todas las funciones prendidas (así arrancan las pruebas).
  final Politicas? politicas;

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
  late final ConectividadViewModel _conectividad;
  late final HistorialViewModel _historial;
  late final Politicas _politicas;

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
    _politicas = widget.politicas ?? Politicas();
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
      // Política: solo si el celular puede programar avisos y el servidor
      // tiene la función prendida.
      recordatorios: _politicas.recuerdaCarritoOlvidado
          ? dependencias.recordatorios
          : null,
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
    _conectividad =
        ConectividadViewModel(repositorio: dependencias.conectividad);
    _historial = HistorialViewModel(
      repositorio: dependencias.historial,
      pagos: dependencias.pago,
    );
    // Al abrir: cinco tareas independientes. Con Future.wait corren en
    // paralelo y el arranque tarda lo que la más lenta, no la suma. (Si
    // la app se cerró con un pedido en viaje, "Mi pedido" lo retoma.)
    unawaited(
      Future.wait([
        _catalogo.cargar(),
        _carrito.restaurar(),
        _seguimiento.restaurar(),
        _historial.cargar(),
        _conectividad.revisar(),
      ]),
    );
    // Al tocar una notificación, la barra cambia de sección; acá se cierra
    // lo que haya encima para que esa sección se vea.
    _suscripcionAvisos =
        _navegacion.abiertasPorAviso.listen((_) => _volverAlInicio());
    // Al final: los que observan los avisos ya están suscriptos, así no se
    // pierden el aviso que abrió la app.
    unawaited(_avisos.iniciar());

    // Cuando la persona sale de la app (o atiende una llamada), el sistema
    // puede cerrarla sin avisar: es el último momento seguro para guardar.
    // onHide además de onPause: en Web y escritorio nunca se llega a
    // paused. Y al volver (onShow/onResume) se cancela el recordatorio del
    // carrito y se revisa la red.
    _cicloDeVida = AppLifecycleListener(
      onHide: _alOcultarse,
      onPause: _alOcultarse,
      onShow: _alVolver,
      onResume: _alVolver,
    );
  }

  void _alOcultarse() => unawaited(_carrito.alOcultarseLaApp());

  void _alVolver() {
    unawaited(_carrito.alVolverALaApp());
    unawaited(_conectividad.revisar());
  }

  /// Rutas con nombre: el ÚNICO lugar que sabe cómo se arma cada pantalla
  /// que se abre encima (y con qué ViewModel). Las pantallas solo hacen
  /// `Navigator.pushNamed(context, Rutas.pago)`.
  Route<void>? _generarRuta(RouteSettings ajustes) {
    final dependencias = widget.dependencias;
    final Widget? pantalla = switch (ajustes.name) {
      Rutas.ingresar => IngresarScreen(
          viewModel: _sesion,
          pista: Politicas.muestraCuentasDeDemo
              ? dependencias.pistaClaves
              : null,
          crearRecuperacion: (email) => RecuperarClaveViewModel(
            repositorio: dependencias.sesion,
            email: email,
          ),
        ),
      Rutas.pago => PagoScreen(
          viewModel: PagoViewModel(
            repositorio: dependencias.pago,
            armarPedido: _carrito.armarPedido,
            politicas: _politicas,
          ),
          items: _carrito.items,
          total: _carrito.total,
          alVerPedido: () => _navegacion.irA(Seccion.miPedido),
          crearElegirUbicacion: (inicial, direccion) =>
              ElegirUbicacionViewModel(
            repositorio: dependencias.ubicacionEntrega,
            inicial: inicial,
            direccionInicial: direccion,
          ),
        ),
      Rutas.cargarConFoto => EscanerScreen(viewModel: _escaner),
      _ => null,
    };
    if (pantalla == null) return null;
    // La pantalla se arma UNA vez (afuera del builder): el builder puede
    // volver a correr y la pantalla de pago es dueña de su ViewModel.
    return MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => pantalla,
    );
  }

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
    _conectividad.dispose();
    _historial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navegador,
      title: 'FreshMarket',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      onGenerateRoute: _generarRuta,
      home: InicioScreen(
        navegacion: _navegacion,
        catalogo: _catalogo,
        carrito: _carrito,
        seguimiento: _seguimiento,
        sesion: _sesion,
        almacen: _almacen,
        reparto: _reparto,
        avisos: _avisos,
        conectividad: _conectividad,
        historial: _historial,
        permiteCargaConFoto: _politicas.permiteCargaConFoto,
      ),
    );
  }
}
