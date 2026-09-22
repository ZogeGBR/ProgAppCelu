import 'package:flutter/material.dart';
import '../models/producto.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(producto.emoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '\$${producto.precio.toStringAsFixed(0)} · ${producto.categoria}',
        ),
        trailing: cantidadEnCarrito == 0
            ? FilledButton(
                onPressed: onAgregar,
                child: const Text('Agregar'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onQuitar,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$cantidadEnCarrito',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
      ),
    );
  }
}
