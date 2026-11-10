/// Lo que responde Mercado Pago (a través de nuestro backend) sobre un pago.
enum ResultadoPago {
  aprobado,
  pendiente,
  rechazado;

  /// Traduce el texto del backend. Cualquier estado desconocido se
  /// trata como pendiente: nunca se da por aprobado algo que no lo es.
  static ResultadoPago desdeTexto(String texto) => switch (texto) {
        'aprobado' => ResultadoPago.aprobado,
        'rechazado' => ResultadoPago.rechazado,
        _ => ResultadoPago.pendiente,
      };
}
