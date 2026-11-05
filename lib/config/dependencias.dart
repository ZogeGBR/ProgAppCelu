import '../data/repositories/catalogo_repository.dart';
import '../data/repositories/etiquetado_repository.dart';
import '../data/repositories/pago_repository.dart';
import '../data/repositories/seguimiento_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/camara_service.dart';
import '../data/services/catalogo_service.dart';
import '../data/services/etiquetado_service.dart';
import '../data/services/pago_service.dart';
import '../data/services/seguimiento_service.dart';

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
  static const mostrarModoDueno =
      bool.fromEnvironment('MODO_DUENO', defaultValue: true);

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
    this.mostrarModoDueno = true,
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
      mostrarModoDueno: AppConfig.mostrarModoDueno,
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
      mostrarModoDueno: AppConfig.mostrarModoDueno,
    );
  }

  final CatalogoRepository catalogo;
  final SeguimientoRepository seguimiento;
  final EtiquetadoRepository etiquetado;
  final PagoRepository pago;
  final bool mostrarModoDueno;
}
