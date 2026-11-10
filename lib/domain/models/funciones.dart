/// Funciones que el backend puede prender o apagar sin publicar otra
/// versión de la app (chequeo "desde el servidor" de la teoría de
/// capacidades y políticas).
///
/// Por ejemplo: si un día el repartidor no puede manejar efectivo, Don
/// Ceferino apaga `pagoEnEfectivo` en el servidor y la opción desaparece de
/// todos los celulares al abrir la app.
class Funciones {
  const Funciones({
    this.pagoEnEfectivo = true,
    this.cargaConFoto = true,
    this.recordatorioCarrito = true,
  });

  /// Si el servidor no responde, se usa esto: todo prendido.
  static const porDefecto = Funciones();

  factory Funciones.fromJson(Map<String, dynamic> json) => Funciones(
        pagoEnEfectivo: json['pagoEnEfectivo'] as bool? ?? true,
        cargaConFoto: json['cargaConFoto'] as bool? ?? true,
        recordatorioCarrito: json['recordatorioCarrito'] as bool? ?? true,
      );

  final bool pagoEnEfectivo;
  final bool cargaConFoto;
  final bool recordatorioCarrito;
}
