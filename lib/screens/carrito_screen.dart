import 'package:flutter/material.dart';
import '../providers/carrito_provider.dart';
import 'metodo_pago_screen.dart';

/// Pantalla del carrito de compras.
///
/// Muestra los ítems ya agregados y el total a pagar, escuchando al
/// CarritoProvider con ListenableBuilder.
class CarritoScreen extends StatelessWidget {
  final CarritoProvider carrito;

  const CarritoScreen({super.key, required this.carrito});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu pedido')),
      body: ListenableBuilder(
        listenable: carrito,
        builder: (context, _) {
          if (carrito.items.isEmpty) {
            return const Center(
              child: Text('Todavía no agregaste productos.'),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: carrito.items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = carrito.items[index];
                    return ListTile(
                      leading: Text(
                        item.producto.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(item.producto.nombre),
                      subtitle: Text('Cantidad: ${item.cantidad}'),
                      trailing: Text('\$${item.subtotal.toStringAsFixed(0)}'),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${carrito.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MetodoPagoScreen(carrito: carrito),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Confirmar pedido'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
