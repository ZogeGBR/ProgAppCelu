import 'package:flutter/material.dart';

import '../../../domain/models/producto.dart';
import '../../core/formato.dart';
import 'selector_cantidad.dart';

/// Tarjeta de un producto del catálogo.
///
/// Patrón de callbacks: la tarjeta no cambia el carrito, solo avisa
/// con [onAgregar] y [onQuitar].
class ProductoCard extends StatelessWidget {
  const ProductoCard({
    super.key,
    required this.producto,
    required this.cantidadEnCarrito,
    required this.onAgregar,
    required this.onQuitar,
    this.onVerDetalle,
  });

  final Producto producto;
  final int cantidadEnCarrito;
  final VoidCallback onAgregar;
  final VoidCallback onQuitar;

  /// Tocar la tarjeta o mantenerla apretada (gesto) abre el detalle.
  /// Mantener apretado es un atajo: tocar hace lo mismo, así nadie se
  /// queda sin ver el detalle por no conocer el gesto.
  final VoidCallback? onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onVerDetalle,
        onLongPress: onVerDetalle,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    producto.emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatearPrecio(producto.precio),
                        style: tema.textTheme.titleLarge?.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // El botón ocupa todo el ancho: es el blanco más fácil de tocar.
            if (!producto.disponible && cantidadEnCarrito == 0)
              const FilledButton.tonal(
                onPressed: null,
                child: Text('Hoy no hay'),
              )
            else if (cantidadEnCarrito == 0)
              FilledButton.tonalIcon(
                onPressed: onAgregar,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar'),
              )
            else
              Row(
                children: [
                  const Expanded(child: Text('En tu carrito:')),
                  SelectorCantidad(
                    cantidad: cantidadEnCarrito,
                    onSumar: onAgregar,
                    onRestar: onQuitar,
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }
}
