import 'package:flutter/material.dart';

import '../../../domain/models/item_carrito.dart';
import '../../../domain/models/pedido_anterior.dart';
import '../../core/formato.dart';
import '../../pago/widgets/metodo_pago_ui.dart';

/// Lista de pedidos anteriores con "Volver a pedir".
///
/// Pensado para el cliente de siempre: la yerba, la leche y el pan de cada
/// semana se piden otra vez con un solo botón.
class HistorialDePedidos extends StatelessWidget {
  const HistorialDePedidos({
    super.key,
    required this.pedidos,
    required this.alVolverAPedir,
    required this.alIrAComprar,
  });

  final List<PedidoAnterior> pedidos;
  final void Function(List<ItemCarrito> items) alVolverAPedir;
  final VoidCallback alIrAComprar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'No tenés ningún pedido en camino.',
          style: tema.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text('¿Querés repetir alguno de los anteriores?'),
        const SizedBox(height: 16),
        for (final pedido in pedidos)
          _TarjetaPedidoAnterior(
            pedido: pedido,
            alVolverAPedir: () => alVolverAPedir(pedido.items),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: alIrAComprar,
          icon: const Icon(Icons.storefront),
          label: const Text('Hacer un pedido nuevo'),
        ),
      ],
    );
  }
}

class _TarjetaPedidoAnterior extends StatelessWidget {
  const _TarjetaPedidoAnterior({
    required this.pedido,
    required this.alVolverAPedir,
  });

  final PedidoAnterior pedido;
  final VoidCallback alVolverAPedir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fecha = pedido.fecha;
    final resumen = pedido.items
        .map((item) => '${item.cantidad} × ${item.producto.nombre}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${pedido.numero} · '
                    '${fecha.day}/${fecha.month}/${fecha.year}',
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatearPrecio(pedido.total),
                  style: tema.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              resumen,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Pagado con: ${pedido.metodoPago.nombre}',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: alVolverAPedir,
              icon: const Icon(Icons.replay),
              label: const Text('Volver a pedir'),
            ),
          ],
        ),
      ),
    );
  }
}
