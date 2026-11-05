import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

/// Habla con Mercado Pago a través de nuestro backend.
///
/// La app NUNCA tiene el Access Token de Mercado Pago: el backend crea
/// la preferencia de pago (y recalcula el total con sus propios precios)
/// y la app solo abre el link de pago que recibe.
abstract interface class PagoService {
  /// Devuelve `{'preferenciaId': ..., 'urlCheckout': ...}`.
  Future<Map<String, dynamic>> crearPreferencia(Map<String, dynamic> pedido);

  /// Devuelve `{'estado': 'aprobado' | 'pendiente' | 'rechazado'}`.
  Future<Map<String, dynamic>> consultarEstado(String pedidoId);
}

/// Abre el checkout de Mercado Pago. Si la app de Mercado Pago está
/// instalada, Android/iOS la abren directo; si no, se abre el navegador.
abstract interface class CheckoutLauncher {
  Future<bool> abrir(Uri url);
}

class PagoServiceHttp implements PagoService {
  const PagoServiceHttp(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> crearPreferencia(
    Map<String, dynamic> pedido,
  ) async {
    return await _api.post('/pagos/preferencia', pedido)
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> consultarEstado(String pedidoId) async {
    return await _api.get('/pagos/$pedidoId/estado') as Map<String, dynamic>;
  }
}

class CheckoutLauncherExterno implements CheckoutLauncher {
  const CheckoutLauncherExterno();

  @override
  Future<bool> abrir(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Pago de mentira para demo y pruebas: aprueba todo después de [demora].
class PagoServiceSimulado implements PagoService {
  const PagoServiceSimulado({
    this.demora = const Duration(milliseconds: 800),
    this.resultado = 'aprobado',
  });

  final Duration demora;
  final String resultado;

  @override
  Future<Map<String, dynamic>> crearPreferencia(
    Map<String, dynamic> pedido,
  ) async {
    await Future<void>.delayed(demora);
    return {
      'preferenciaId': 'simulada-${pedido['id']}',
      'urlCheckout': 'https://www.mercadopago.com.ar/',
    };
  }

  @override
  Future<Map<String, dynamic>> consultarEstado(String pedidoId) async =>
      {'estado': resultado};
}

/// No abre nada: en modo simulado no hay checkout real.
class CheckoutLauncherSimulado implements CheckoutLauncher {
  const CheckoutLauncherSimulado();

  @override
  Future<bool> abrir(Uri url) async => true;
}
