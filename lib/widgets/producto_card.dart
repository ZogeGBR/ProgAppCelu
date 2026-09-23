import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../utils/formato.dart';
import 'selector_cantidad.dart';

/// Tarjeta de un producto del catálogo.
///
/// Sigue el patrón de callbacks del apunte: este widget hijo NO
/// decide por sí mismo el estado del carrito — solo avisa al padre
/// (mediante onAgregar / onQuitar) y el padre decide qué hacer,
/// igual que ShoppingListItem con onCartChanged.
class ProductoCard extends StatelessWidget {
  final Producto producto;
  final int cantidadEnCarrito;
  final VoidCallback onAgregar;
  final VoidCallback onQuitar;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.cantidadEnCarrito,
    required this.onAgregar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(producto.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producto.categoria,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatearPrecio(producto.precio),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            cantidadEnCarrito == 0
                ? FilledButton.tonalIcon(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  )
                : SelectorCantidad(
                    cantidad: cantidadEnCarrito,
                    onSumar: onAgregar,
                    onRestar: onQuitar,
                  ),
          ],
        ),
      ),
    );
  }
}
