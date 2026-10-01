import 'package:flutter/material.dart';

/// Control "−  2  +" para cambiar la cantidad de un producto.
///
/// Igual que ProductoCard, no toca el carrito: solo avisa al padre
/// con los callbacks onSumar / onRestar.
class SelectorCantidad extends StatelessWidget {
  final int cantidad;
  final VoidCallback onSumar;
  final VoidCallback onRestar;

  const SelectorCantidad({
    super.key,
    required this.cantidad,
    required this.onSumar,
    required this.onRestar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Quitar uno',
            onPressed: onRestar,
            icon: Icon(
              cantidad == 1 ? Icons.delete_outline : Icons.remove,
              size: 20,
            ),
          ),
          // AnimatedSwitcher hace que el número "salte" al cambiar.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$cantidad',
              key: ValueKey(cantidad),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Agregar uno',
            onPressed: onSumar,
            icon: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );
  }
}
