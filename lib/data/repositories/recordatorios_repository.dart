import '../services/recordatorio_service.dart';

/// Recordatorios que el celular muestra solo, aunque la app esté cerrada.
///
/// Hoy hay uno: "Te quedaron productos en el carrito". Se programa cuando
/// la persona sale de la app con el carrito lleno y se cancela cuando
/// vuelve (o cuando compra).
class RecordatoriosRepository {
  RecordatoriosRepository({
    required RecordatorioService service,
    DateTime Function()? reloj,
    this.esperaCarrito = const Duration(hours: 2),
  })  : _service = service,
        _reloj = reloj ?? DateTime.now;

  /// Un id fijo: si se programa dos veces, el segundo reemplaza al primero.
  static const idCarrito = 9001;

  final RecordatorioService _service;
  final DateTime Function() _reloj;
  final Duration esperaCarrito;

  Future<void> recordarCarrito(int cantidadDeProductos) => _service.programar(
        id: idCarrito,
        titulo: 'Te quedó un pedido sin terminar',
        cuerpo: cantidadDeProductos == 1
            ? 'Tenés 1 producto en el carrito. ¿Lo pedimos?'
            : 'Tenés $cantidadDeProductos productos en el carrito. '
                '¿Los pedimos?',
        cuando: _reloj().add(esperaCarrito),
      );

  Future<void> olvidarCarrito() => _service.cancelar(idCarrito);
}
