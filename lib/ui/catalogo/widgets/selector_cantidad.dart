import 'package:flutter/material.dart';

/// Control "−  2  +" para cambiar la cantidad de un producto.
///
/// No toca el carrito: avisa al padre con [onSumar] y [onRestar]
/// (patrón de callbacks). Los botones miden 48 dp, el mínimo para
/// tocarlos cómodo.
class SelectorCantidad extends StatelessWidget {
  const SelectorCantidad({
    super.key,
    required this.cantidad,
    required this.onSumar,
    required this.onRestar,
  });

  final int cantidad;
  final VoidCallback onSumar;
  final VoidCallback onRestar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colores.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 26,
            tooltip: cantidad == 1 ? 'Sacar del carrito' : 'Quitar uno',
            onPressed: onRestar,
            icon: Icon(cantidad == 1 ? Icons.delete_outline : Icons.remove),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animacion) =>
                ScaleTransition(scale: animacion, child: child),
            child: Text(
              '$cantidad',
              key: ValueKey(cantidad),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colores.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            iconSize: 26,
            tooltip: 'Agregar uno',
            onPressed: onSumar,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
