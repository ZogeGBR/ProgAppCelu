import 'package:flutter/material.dart';
import '../models/item_carrito.dart';
import '../providers/carrito_provider.dart';
import '../utils/formato.dart';
import '../widgets/selector_cantidad.dart';
import 'metodo_pago_screen.dart';

/// Pantalla del carrito de compras.
///
/// Muestra los ítems ya agregados y el total a pagar, escuchando al
/// CarritoProvider con ListenableBuilder. Desde acá se pueden cambiar
/// cantidades, deslizar un ítem para sacarlo o vaciar todo.
class CarritoScreen extends StatelessWidget {
  final CarritoProvider carrito;

  const CarritoScreen({super.key, required this.carrito});

  Future<void> _confirmarVaciar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar el carrito?'),
        content: const Text('Se van a sacar todos los productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmado == true) carrito.vaciarCarrito();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: carrito,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tu pedido'),
            actions: [
              if (!carrito.estaVacio)
                IconButton(
                  tooltip: 'Vaciar carrito',
                  onPressed: () => _confirmarVaciar(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: carrito.estaVacio
              ? const _CarritoVacio()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: carrito.items.length,
                  itemBuilder: (context, index) {
                    final item = carrito.items[index];
                    return _ItemCarritoTile(
                      item: item,
                      onSumar: () => carrito.agregarProducto(item.producto),
                      onRestar: () => carrito.quitarProducto(item.producto),
                      onEliminar: () {
                        carrito.eliminarProducto(item.producto);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sacaste ${item.producto.nombre} del pedido',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
          bottomNavigationBar:
              carrito.estaVacio ? null : _ResumenTotal(carrito: carrito),
        );
      },
    );
  }
}

/// Un renglón del carrito. Se puede deslizar hacia la izquierda para
/// eliminarlo (Dismissible).
class _ItemCarritoTile extends StatelessWidget {
  final ItemCarrito item;
  final VoidCallback onSumar;
  final VoidCallback onRestar;
  final VoidCallback onEliminar;

  const _ItemCarritoTile({
    required this.item,
    required this.onSumar,
    required this.onRestar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(item.producto.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onEliminar(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Text(item.producto.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          item.producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatearPrecio(item.producto.precio)} c/u · '
          '${formatearPrecio(item.subtotal)}',
        ),
        trailing: SelectorCantidad(
          cantidad: item.cantidad,
          onSumar: onSumar,
          onRestar: onRestar,
        ),
      ),
    );
  }
}

class _ResumenTotal extends StatelessWidget {
  final CarritoProvider carrito;

  const _ResumenTotal({required this.carrito});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total (${carrito.cantidadTotal} productos)',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  formatearPrecio(carrito.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MetodoPagoScreen(carrito: carrito),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Ir a pagar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarritoVacio extends StatelessWidget {
  const _CarritoVacio();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket_outlined,
                size: 72, color: colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'Todavía no agregaste productos.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.storefront),
              label: const Text('Ir al catálogo'),
            ),
          ],
        ),
      ),
    );
  }
}
