import 'dart:async';
import 'dart:convert';

import '../../domain/models/limite_de_pedidos.dart';
import '../../domain/models/metodo_pago.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resultado_pago.dart';
import '../services/api_client.dart';
import '../services/pago_service.dart';

/// Cobra un pedido con Mercado Pago.
///
/// 1. Pide al backend la preferencia de pago (con el total recalculado
///    por el servidor).
/// 2. Abre el checkout (app de Mercado Pago o navegador).
/// 3. Consulta el estado cada [intervaloConsulta] hasta [limiteEspera].
///
/// Patrón Observer: cuando un pedido queda confirmado (pago aprobado, o
/// efectivo), el repositorio lo publica en [pedidosConfirmados]. El
/// carrito se vacía y "Mi pedido" empieza a seguirlo porque lo observan;
/// la pantalla de pago no sabe que existen.
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

  final _confirmados = StreamController<Pedido>.broadcast(sync: true);
  final _idsConfirmados = <String>{};

  /// Emite cada pedido una sola vez, cuando queda confirmado.
  Stream<Pedido> get pedidosConfirmados => _confirmados.stream;

  /// Registra el pedido y, salvo en efectivo, abre Mercado Pago.
  ///
  /// Devuelve el pedido con el número que asignó el servidor: si lo eligiera
  /// cada celular, dos clientes tendrían el mismo. Sin backend (demo) queda
  /// el número local. En efectivo el pedido ya queda confirmado: se paga al
  /// recibir.
  ///
  /// Si el almacén llegó a su tope (100 pedidos por día o por minuto), el
  /// servidor responde 429 y se lanza [SinLugarParaPedidos]: la capa de
  /// datos traduce el código HTTP a algo del dominio, y el ViewModel nunca
  /// ve un `ApiException`.
  Future<Pedido> iniciarPago(Pedido pedido) async {
    final Map<String, dynamic> preferencia;
    try {
      preferencia = await _service.crearPreferencia(pedido.toJson());
    } on ApiException catch (error) {
      if (error.codigo == 429) throw SinLugarParaPedidos(_limiteDe(error));
      rethrow;
    }
    final url = preferencia['urlCheckout'] as String?;
    if (url != null) {
      final seAbrio = await _checkout.abrir(Uri.parse(url));
      if (!seAbrio) throw const PagoException('No se pudo abrir Mercado Pago.');
    }
    final registrado = pedido.copiarCon(numero: preferencia['numero'] as int?);
    if (registrado.metodoPago == MetodoPago.efectivo) _confirmar(registrado);
    return registrado;
  }

  /// Emite el estado del pago en cada consulta. Termina solo al pasar
  /// [limiteEspera]; quien escucha cancela antes si llega una respuesta
  /// definitiva (aprobado o rechazado).
  Stream<ResultadoPago> seguirEstado(Pedido pedido) {
    final consultas =
        limiteEspera.inMilliseconds ~/ intervaloConsulta.inMilliseconds;
    return Stream<void>.periodic(intervaloConsulta)
        .asyncMap((_) => _consultar(pedido))
        .take(consultas < 1 ? 1 : consultas);
  }

  Future<ResultadoPago> _consultar(Pedido pedido) async {
    final datos = await _service.consultarEstado(pedido.id);
    final resultado = ResultadoPago.desdeTexto(datos['estado'] as String);
    if (resultado == ResultadoPago.aprobado) _confirmar(pedido);
    return resultado;
  }

  /// El servidor dice qué tope se alcanzó (`{"limite": "porDia"}`). Si no
  /// se entiende la respuesta, se asume el del minuto: "probá en un minuto"
  /// nunca deja a nadie esperando hasta mañana por error.
  static LimiteDePedidos _limiteDe(ApiException error) {
    try {
      final cuerpo = jsonDecode(error.cuerpo);
      if (cuerpo is Map && cuerpo['limite'] == 'porDia') {
        return LimiteDePedidos.porDia;
      }
    } on FormatException {
      // Respuesta que no es JSON: se usa el valor por defecto.
    }
    return LimiteDePedidos.porMinuto;
  }

  void _confirmar(Pedido pedido) {
    // Dos consultas seguidas pueden decir "aprobado": se avisa una vez.
    if (_idsConfirmados.add(pedido.id)) _confirmados.add(pedido);
  }

  void dispose() => unawaited(_confirmados.close());
}

class PagoException implements Exception {
  const PagoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'PagoException: $mensaje';
}
