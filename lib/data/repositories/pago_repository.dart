import '../../domain/models/pedido.dart';
import '../../domain/models/resultado_pago.dart';
import '../services/pago_service.dart';

/// Cobra un pedido con Mercado Pago.
///
/// 1. Pide al backend la preferencia de pago (con el total recalculado
///    por el servidor).
/// 2. Abre el checkout (app de Mercado Pago o navegador).
/// 3. Consulta el estado cada [intervaloConsulta] hasta [limiteEspera].
class PagoRepository {
  PagoRepository({
    required PagoService service,
    required CheckoutLauncher checkout,
    this.intervaloConsulta = const Duration(seconds: 3),
    this.limiteEspera = const Duration(minutes: 5),
  })  : _service = service,
        _checkout = checkout;

  final PagoService _service;
  final CheckoutLauncher _checkout;
  final Duration intervaloConsulta;
  final Duration limiteEspera;

  /// Registra el pedido y, salvo en efectivo, abre Mercado Pago.
  ///
  /// Devuelve el pedido con el número que asignó el servidor: si lo eligiera
  /// cada celular, dos clientes tendrían el mismo. Sin backend (demo) queda
  /// el número local.
  Future<Pedido> iniciarPago(Pedido pedido) async {
    final preferencia = await _service.crearPreferencia(pedido.toJson());
    final url = preferencia['urlCheckout'] as String?;
    if (url != null) {
      final seAbrio = await _checkout.abrir(Uri.parse(url));
      if (!seAbrio) throw const PagoException('No se pudo abrir Mercado Pago.');
    }
    return pedido.copiarCon(numero: preferencia['numero'] as int?);
  }

  /// Emite el estado del pago en cada consulta. Termina solo al pasar
  /// [limiteEspera]; quien escucha cancela antes si llega una respuesta
  /// definitiva (aprobado o rechazado).
  Stream<ResultadoPago> seguirEstado(String pedidoId) {
    final consultas =
        limiteEspera.inMilliseconds ~/ intervaloConsulta.inMilliseconds;
    return Stream<void>.periodic(intervaloConsulta)
        .asyncMap((_) => _consultar(pedidoId))
        .take(consultas < 1 ? 1 : consultas);
  }

  Future<ResultadoPago> _consultar(String pedidoId) async {
    final datos = await _service.consultarEstado(pedidoId);
    return ResultadoPago.desdeTexto(datos['estado'] as String);
  }
}

class PagoException implements Exception {
  const PagoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'PagoException: $mensaje';
}
