import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../providers/carrito_provider.dart';
import '../widgets/producto_card.dart';
import 'carrito_screen.dart';

/// Pantalla principal: catálogo de FreshMarket.
///
/// Es Stateless porque la lista de productos no cambia; lo único que
/// cambia es el carrito, y ese estado vive afuera (en
/// CarritoProvider). Por eso envolvemos las partes que dependen del
/// carrito en ListenableBuilder, tal como recomienda el apunte en
/// vez de usar addListener a mano.
class HomeScreen extends StatelessWidget {
  final CarritoProvider carrito;

  const HomeScreen({super.key, required this.carrito});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FreshMarket'),
        actions: [
          ListenableBuilder(
            listenable: carrito,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CarritoScreen(carrito: carrito),
                        ),
                      );
                    },
                  ),
                  if (carrito.cantidadTotal > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Badge(label: Text('${carrito.cantidadTotal}')),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: carrito,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: catalogoFreshMarket.map((Producto producto) {
              return ProductoCard(
                producto: producto,
                cantidadEnCarrito: carrito.cantidadDe(producto),
                onAgregar: () => carrito.agregarProducto(producto),
                onQuitar: () => carrito.quitarProducto(producto),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
