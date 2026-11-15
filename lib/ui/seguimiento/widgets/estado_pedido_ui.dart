import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';

/// Textos e íconos de cada etapa del pedido (son de la vista).
extension EstadoPedidoUi on EstadoPedido {
  String get titulo => switch (this) {
        EstadoPedido.recibido => 'Pedido recibido',
        EstadoPedido.enPreparacion => 'Preparando tu pedido',
        EstadoPedido.enCamino => 'En camino en bicicleta',
        EstadoPedido.entregado => '¡Entregado!',
      };

  String get descripcion => switch (this) {
        EstadoPedido.recibido => 'Don Ceferino ya vio tu pedido.',
        EstadoPedido.enPreparacion => 'Están armando tu bolsa en el almacén.',
        EstadoPedido.enCamino => 'Mirá en el mapa por dónde va.',
        EstadoPedido.entregado => 'Que lo disfrutes.',
      };

  IconData get icono => switch (this) {
        EstadoPedido.recibido => Icons.receipt_long,
        EstadoPedido.enPreparacion => Icons.storefront,
        EstadoPedido.enCamino => Icons.pedal_bike,
        EstadoPedido.entregado => Icons.check_circle,
      };
}
