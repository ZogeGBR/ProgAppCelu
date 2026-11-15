import '../data/repositories/carrito_repository.dart';
import '../data/repositories/catalogo_repository.dart';
import '../data/repositories/conectividad_repository.dart';
import '../data/repositories/etiquetado_repository.dart';
import '../data/repositories/funciones_repository.dart';
import '../data/repositories/historial_repository.dart';
import '../data/repositories/notificaciones_repository.dart';
import '../data/repositories/pago_repository.dart';
import '../data/repositories/recordatorios_repository.dart';
import '../data/repositories/reparto_repository.dart';
import '../data/repositories/seguimiento_repository.dart';
import '../data/repositories/sesion_repository.dart';
import '../data/repositories/ubicacion_entrega_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/avisos_service.dart';
import '../data/services/camara_service.dart';
import '../data/services/carrito_local_service.dart';
import '../data/services/catalogo_service.dart';
import '../data/services/conectividad_service.dart';
import '../data/services/etiquetado_service.dart';
import '../data/services/funciones_service.dart';
import '../data/services/geocodificacion_service.dart';
import '../data/services/historial_dao.dart';
import '../data/services/notificacion_local_service.dart';
import '../data/services/pago_service.dart';
import '../data/services/pedido_local_service.dart';
import '../data/services/push_service.dart';
import '../data/services/recordatorio_service.dart';
import '../data/services/reparto_service.dart';
import '../data/services/seguimiento_service.dart';
import '../data/services/sesion_service.dart';
import '../data/services/ubicacion_service.dart';
import '../domain/politicas/politicas.dart';

/// Configuración que llega al compilar con `--dart-define`.
///
/// ```
/// flutter run --dart-define=URL_BACKEND=http://10.0.2.2:3000
/// ```
///
/// Sin URL_BACKEND la app arranca en modo demo (todo simulado).
/// Ninguna clave secreta va acá: las de Mercado Pago y de la IA viven
/// solo en el backend.
abstract final class AppConfig {
  static const urlBackend = String.fromEnvironment('URL_BACKEND');

  static bool get usaBackend => urlBackend.isNotEmpty;
}

/// Arma los repositorios con sus servicios (inyección de dependencias).
///
/// Es el ÚNICO lugar donde se decide qué implementación se usa (patrón
/// Factory + Strategy). Para pasar de la demo al backend real no se toca
/// ninguna otra clase. También garantiza que haya UNA sola instancia de
/// cada repositorio y un solo [ApiClient] para toda la app: cumple el rol
/// de un Singleton sin sus problemas (se puede reemplazar en las pruebas).
class Dependencias {
  const Dependencias({
    required this.catalogo,
    required this.seguimiento,
    required this.etiquetado,
    required this.pago,
    required this.sesion,
    required this.reparto,
    required this.carrito,
    required this.ubicacionEntrega,
    required this.notificaciones,
    required this.funciones,
    required this.conectividad,
    required this.recordatorios,
    required this.historial,
    this.pistaClaves,
  });

  /// SQLite en el celular; en Web (donde no existe) el historial vive en
  /// memoria. La decisión la toma la política, no un `if` suelto.
  static HistorialService _historialSegun(Politicas politicas) =>
      politicas.puedeGuardarHistorial
          ? HistorialDao()
          : HistorialServiceMemoria();

  /// [hayFirebase]: si Firebase arrancó (ver main.dart). Sin Firebase la app
  /// anda igual, pero sin notificaciones push del backend.
  factory Dependencias.desdeConfiguracion({bool hayFirebase = false}) {
    if (!AppConfig.usaBackend) return Dependencias.simuladas();

    final api = ApiClient(urlBase: AppConfig.urlBackend);
    final catalogo = CatalogoRepository(service: CatalogoServiceHttp(api));
    final sesion = SesionRepository(service: SesionServiceHttp(api));
    // Observer: el cliente HTTP usa el token de quien haya ingresado.
    sesion.cambios.listen((actual) => api.usarToken(actual?.token));
    return Dependencias(
      catalogo: catalogo,
      seguimiento: SeguimientoRepository(
        service: SeguimientoServiceHttp(api),
        guardado: const PedidoLocalServicePreferencias(),
      ),
      etiquetado: EtiquetadoRepository(
        camara: CamaraServiceImagePicker(),
        etiquetado: EtiquetadoServiceHttp(api),
      ),
      pago: PagoRepository(
        service: PagoServiceHttp(api),
        checkout: const CheckoutLauncherExterno(),
      ),
      sesion: sesion,
      reparto: RepartoRepository(
        service: RepartoServiceHttp(api),
        ubicacion: const UbicacionServiceGeolocator(),
      ),
      carrito: CarritoRepository(
        service: const CarritoLocalServicePreferencias(),
      ),
      ubicacionEntrega: UbicacionEntregaRepository(
        geocodificacion: GeocodificacionServiceHttp(api),
        gps: const UbicacionServiceGeolocator(),
      ),
      notificaciones: NotificacionesRepository(
        // Sin Firebase, un push que nunca recibe nada y no tiene token: la
        // app no se rompe y no anota nada en el backend.
        push: hayFirebase
            ? PushServiceFirebase()
            : PushServiceSimulado(token: null),
        local: NotificacionLocalServicePlugin(),
        servidor: AvisosServiceHttp(api),
      ),
      funciones: FuncionesRepository(service: FuncionesServiceHttp(api)),
      conectividad:
          ConectividadRepository(service: ConectividadServicePlus()),
      recordatorios:
          RecordatoriosRepository(service: RecordatorioServicePlugin()),
      historial: HistorialRepository(service: _historialSegun(Politicas())),
    );
  }

  /// Todo simulado: sirve para la demo en clase y para las pruebas.
  /// Las pruebas pueden reemplazar cualquier pieza por un falso.
  factory Dependencias.simuladas({
    CatalogoService? catalogoService,
    SeguimientoService? seguimientoService,
    CamaraService? camara,
    EtiquetadoService? etiquetadoService,
    PagoService? pagoService,
    SesionService? sesionService,
    RepartoService? repartoService,
    UbicacionService? ubicacionService,
    CarritoLocalService? carritoLocalService,
    PedidoLocalService? pedidoLocalService,
    GeocodificacionService? geocodificacionService,
    NotificacionLocalService? notificacionLocal,
    PushService? push,
    FuncionesService? funcionesService,
    ConectividadService? conectividadService,
    RecordatorioService? recordatorioService,
    HistorialService? historialService,
    Duration intervaloPago = const Duration(seconds: 1),
  }) {
    // El "servidor" de la demo manda los avisos por este push simulado.
    final pushDemo = PushServiceSimulado();
    return Dependencias(
      catalogo: CatalogoRepository(
        service: catalogoService ?? CatalogoServiceLocal(),
      ),
      seguimiento: SeguimientoRepository(
        service:
            seguimientoService ?? SeguimientoServiceSimulado(push: pushDemo),
        guardado: pedidoLocalService ?? const PedidoLocalServicePreferencias(),
      ),
      etiquetado: EtiquetadoRepository(
        camara: camara ?? CamaraServiceImagePicker(),
        etiquetado: etiquetadoService ?? const EtiquetadoServiceSimulado(),
      ),
      pago: PagoRepository(
        service: pagoService ?? const PagoServiceSimulado(),
        checkout: const CheckoutLauncherSimulado(),
        intervaloConsulta: intervaloPago,
      ),
      sesion: SesionRepository(
        service: sesionService ?? SesionServiceSimulado(),
      ),
      reparto: RepartoRepository(
        service: repartoService ?? RepartoServiceSimulado(),
        ubicacion: ubicacionService ?? const UbicacionServiceGeolocator(),
      ),
      carrito: CarritoRepository(
        service: carritoLocalService ?? const CarritoLocalServicePreferencias(),
      ),
      ubicacionEntrega: UbicacionEntregaRepository(
        geocodificacion:
            geocodificacionService ?? const GeocodificacionServiceSimulado(),
        gps: ubicacionService ?? const UbicacionServiceGeolocator(),
      ),
      notificaciones: NotificacionesRepository(
        push: push ?? pushDemo,
        local: notificacionLocal ?? NotificacionLocalServicePlugin(),
        servidor: const AvisosServiceSimulado(),
      ),
      funciones: FuncionesRepository(
        service: funcionesService ?? const FuncionesServiceSimulado(),
      ),
      conectividad: ConectividadRepository(
        service: conectividadService ?? ConectividadServicePlus(),
      ),
      recordatorios: RecordatoriosRepository(
        service: recordatorioService ?? RecordatorioServicePlugin(),
      ),
      historial: HistorialRepository(
        service: historialService ?? _historialSegun(Politicas()),
      ),
      pistaClaves: 'Demo: ${SesionServiceSimulado.emailDueno} o '
          '${SesionServiceSimulado.emailRepartidor}, contraseña '
          '"${SesionServiceSimulado.claveInicial}". Si la olvidás, el '
          'código es ${SesionServiceSimulado.codigoDemo}.',
    );
  }

  final CatalogoRepository catalogo;
  final SeguimientoRepository seguimiento;
  final EtiquetadoRepository etiquetado;
  final PagoRepository pago;
  final SesionRepository sesion;
  final RepartoRepository reparto;
  final CarritoRepository carrito;
  final UbicacionEntregaRepository ubicacionEntrega;
  final NotificacionesRepository notificaciones;
  final FuncionesRepository funciones;
  final ConectividadRepository conectividad;
  final RecordatoriosRepository recordatorios;
  final HistorialRepository historial;

  /// Solo en la demo: qué cuentas se pueden usar para ingresar.
  final String? pistaClaves;
}
