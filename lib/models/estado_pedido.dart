/// Estados posibles de un pedido en curso.
///
/// Don Ceferino pidió poder ver "como el GPS de un taxi" en qué va
/// el pedido. En esta etapa de la materia todavía no vimos
/// geolocalización ni mapas reales, así que lo simulamos con un
/// progreso por etapas. Queda como punto de extensión para integrar
/// un mapa real más adelante (ver comentario en SeguimientoScreen).
enum EstadoPedido {
  recibido,
  enPreparacion,
  enCamino,
  entregado,
}

extension EstadoPedidoInfo on EstadoPedido {
  String get titulo {
    switch (this) {
      case EstadoPedido.recibido:
        return 'Pedido recibido';
      case EstadoPedido.enPreparacion:
        return 'Preparando tu pedido';
      case EstadoPedido.enCamino:
        return 'En camino';
      case EstadoPedido.entregado:
        return '¡Entregado!';
    }
  }

  String get descripcion {
    switch (this) {
      case EstadoPedido.recibido:
        return 'Don Ceferino ya vio tu pedido.';
      case EstadoPedido.enPreparacion:
        return 'Están armando tu bolsa en el almacén.';
      case EstadoPedido.enCamino:
        return 'El repartidor va para tu casa.';
      case EstadoPedido.entregado:
        return 'Que lo disfrutes.';
    }
  }

  double get progreso {
    switch (this) {
      case EstadoPedido.recibido:
        return 0.25;
      case EstadoPedido.enPreparacion:
        return 0.5;
      case EstadoPedido.enCamino:
        return 0.75;
      case EstadoPedido.entregado:
        return 1.0;
    }
  }
}
