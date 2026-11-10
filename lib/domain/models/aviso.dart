import 'dart:convert';

/// Para qué es un aviso: decide qué sección se abre al tocarlo.
enum TipoAviso {
  /// Novedad del pedido del cliente (salió, llegó): abre "Mi pedido".
  pedido,

  /// Entró un pedido nuevo: abre "Mi almacén" o "Repartir".
  nuevoPedido,
}

/// Una notificación: lo que se ve (título y texto) y para qué es.
///
/// Llega igual por los dos caminos: como push de Firebase (desde el
/// backend) o como notificación local que arma la app. Por eso el modelo
/// vive en el dominio y no depende de ningún paquete.
class Aviso {
  const Aviso({
    required this.titulo,
    required this.cuerpo,
    this.tipo = TipoAviso.pedido,
    this.pedidoId,
  });

  /// Arma el aviso con el título y el texto de la notificación y los
  /// `data` que mandó el backend (`{tipo, pedidoId}`).
  factory Aviso.desdeDatos(
    Map<String, dynamic> datos, {
    String? titulo,
    String? cuerpo,
  }) {
    return Aviso(
      titulo: titulo ?? datos['titulo'] as String? ?? 'FreshMarket',
      cuerpo: cuerpo ?? datos['cuerpo'] as String? ?? '',
      tipo: TipoAviso.values.asNameMap()[datos['tipo']] ?? TipoAviso.pedido,
      pedidoId: datos['pedidoId'] as String?,
    );
  }

  /// Lo inverso de [aTexto]: lo que vuelve cuando se toca una
  /// notificación local. Si el texto está roto, devuelve null.
  static Aviso? desdeTexto(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    try {
      return Aviso.desdeDatos(jsonDecode(texto) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  final String titulo;
  final String cuerpo;
  final TipoAviso tipo;
  final String? pedidoId;

  /// Todo el aviso en un texto: la notificación local lo guarda como
  /// "payload" y lo devuelve al tocarla.
  String aTexto() => jsonEncode({
        'titulo': titulo,
        'cuerpo': cuerpo,
        'tipo': tipo.name,
        if (pedidoId != null) 'pedidoId': pedidoId,
      });

  /// Un número estable para la notificación: un aviso nuevo del mismo
  /// pedido reemplaza al anterior en vez de apilarse.
  int get idNotificacion => (pedidoId ?? titulo).hashCode & 0x7fffffff;
}
