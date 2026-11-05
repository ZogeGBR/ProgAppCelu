import '../data/repositories/catalogo_repository.dart';
import '../data/repositories/etiquetado_repository.dart';
import '../data/repositories/pago_repository.dart';
import '../data/repositories/reparto_repository.dart';
import '../data/repositories/seguimiento_repository.dart';
import '../data/repositories/sesion_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/camara_service.dart';
import '../data/services/catalogo_service.dart';
import '../data/services/etiquetado_service.dart';
import '../data/services/pago_service.dart';
import '../data/services/reparto_service.dart';
import '../data/services/seguimiento_service.dart';
import '../data/services/sesion_service.dart';
import '../data/services/ubicacion_service.dart';

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
/// Es el ÚNICO lugar donde se decide qué implementación se usa. Para
/// pasar de la demo al backend real no se toca ninguna otra clase.
class Dependencias {
  const Dependencias({
    required this.catalogo,
    required this.seguimiento,
    required this.etiquetado,
    required this.pago,
    required this.sesion,
    required this.reparto,
    this.pistaClaves,
  });

  factory Dependencias.desdeConfiguracion() {
    if (!AppConfig.usaBackend) return Dependencias.simuladas();

    final api = ApiClient(urlBase: AppConfig.urlBackend);
    final catalogo = CatalogoRepository(service: CatalogoServiceHttp(api));
    return Dependencias(
      catalogo: catalogo,
      seguimiento: SeguimientoRepository(service: SeguimientoServiceHttp(api)),
      etiquetado: EtiquetadoRepository(
        camara: CamaraServiceImagePicker(),
        etiquetado: EtiquetadoServiceHttp(api),
      ),
      pago: PagoRepository(
        service: PagoServiceHttp(api),
        checkout: const CheckoutLauncherExterno(),
      ),
      sesion: SesionRepository(
        service: SesionServiceHttp(api),
        alCambiarToken: (token) => api.token = token,
      ),
      reparto: RepartoRepository(
        service: RepartoServiceHttp(api),
        ubicacion: const UbicacionServiceGeolocator(),
      ),
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
    Duration intervaloPago = const Duration(seconds: 1),
  }) {
    return Dependencias(
      catalogo: CatalogoRepository(
        service: catalogoService ?? CatalogoServiceLocal(),
      ),
      seguimiento: SeguimientoRepository(
        service: seguimientoService ?? const SeguimientoServiceSimulado(),
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
        service: sesionService ?? const SesionServiceSimulado(),
      ),
      reparto: RepartoRepository(
        service: repartoService ?? RepartoServiceSimulado(),
        ubicacion: ubicacionService ?? const UbicacionServiceGeolocator(),
      ),
      pistaClaves: 'Demo: la clave es "${SesionServiceSimulado.claveDueno}" '
          'o "${SesionServiceSimulado.claveRepartidor}".',
    );
  }

  final CatalogoRepository catalogo;
  final SeguimientoRepository seguimiento;
  final EtiquetadoRepository etiquetado;
  final PagoRepository pago;
  final SesionRepository sesion;
  final RepartoRepository reparto;

  /// Solo en la demo: qué claves se pueden usar para ingresar.
  final String? pistaClaves;
}
