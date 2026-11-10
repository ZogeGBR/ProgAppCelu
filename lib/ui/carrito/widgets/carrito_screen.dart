import 'package:flutter/material.dart';

import '../../../domain/models/item_carrito.dart';
import '../../catalogo/widgets/selector_cantidad.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/carrito_view_model.dart';

/// Sección "Mi carrito": cantidades, total y el botón para pagar.
class CarritoScreen extends StatelessWidget {
  const CarritoScreen({
    super.key,
    required this.carrito,
    required this.alIrAPagar,
    required this.alIrAComprar,
  });

  final CarritoViewModel carrito;
  final VoidCallback alIrAPagar;
  final VoidCallback alIrAComprar;

  Future<void> _confirmarVaciar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar el carrito?'),
        content: const Text('Se van a sacar todos los productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, dejarlo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, vaciar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) carrito.vaciarCarrito();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: carrito,
      builder: (context, _) {
        if (carrito.estaVacio) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi carrito')),
            body: VistaMensaje(
              icono: Icons.shopping_basket_outlined,
              titulo: 'Tu carrito está vacío.',
              detalle: 'Elegí productos en "Comprar" y aparecen acá.',
              textoBoton: 'Ir a comprar',
              onBoton: alIrAComprar,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi carrito'),
            actions: [
              TextButton.icon(
                onPressed: () => _confirmarVaciar(context),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Vaciar'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: carrito.items.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              final item = carrito.items[indice];
              // Gesto: deslizar el renglón lo saca entero. Es un atajo:
              // el botón "−" hace lo mismo y "Deshacer" lo devuelve, por
              // si se deslizó sin querer.
              return Dismissible(
                key: ValueKey(item.producto.id),
                background: const _FondoQuitar(),
                onDismissed: (_) {
                  carrito.eliminarProducto(item.producto);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('Sacaste ${item.producto.nombre}.'),
                        action: SnackBarAction(
                          label: 'Deshacer',
                          onPressed: () => carrito.agregarItems([item]),
                        ),
                      ),
                    );
                },
                child: _RenglonCarrito(
                  item: item,
                  onSumar: () => carrito.agregarProducto(item.producto),
                  onRestar: () => carrito.quitarProducto(item.producto),
                ),
              );
            },
          ),
          bottomNavigationBar: _ResumenTotal(
            cantidad: carrito.cantidadTotal,
            total: carrito.total,
            alIrAPagar: alIrAPagar,
          ),
        );
      },
    );
  }
}

/// Lo que se ve detrás del renglón mientras se desliza.
class _FondoQuitar extends StatelessWidget {
  const _FondoQuitar();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      color: colores.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Sacar',
            style: TextStyle(fontSize: 18, color: colores.onErrorContainer),
          ),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline, color: colores.onErrorContainer),
        ],
      ),
    );
  }
}

/// Un renglón del carrito. Se quita con el botón "−" (que en 1 se
/// convierte en tacho) o deslizándolo.
class _RenglonCarrito extends StatelessWidget {
  const _RenglonCarrito({
    required this.item,
    required this.onSumar,
    required this.onRestar,
  });

  final ItemCarrito item;
  final VoidCallback onSumar;
  final VoidCallback onRestar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(item.producto.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(formatearPrecio(item.subtotal)),
              ],
            ),
          ),
          SelectorCantidad(
            cantidad: item.cantidad,
            onSumar: onSumar,
            onRestar: onRestar,
          ),
        ],
      ),
    );
  }
}

class _ResumenTotal extends StatelessWidget {
  const _ResumenTotal({
    required this.cantidad,
    required this.total,
    required this.alIrAPagar,
  });

  final int cantidad;
  final double total;
  final VoidCallback alIrAPagar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border:
              Border(top: BorderSide(color: tema.colorScheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($cantidad ${cantidad == 1 ? 'producto' : 'productos'})',
                  style: tema.textTheme.titleMedium,
                ),
                Text(
                  formatearPrecio(total),
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: alIrAPagar,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Ir a pagar'),
            ),
          ],
        ),
      ),
    );
  }
}
