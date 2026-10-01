import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../providers/carrito_provider.dart';
import '../utils/formato.dart';
import '../widgets/producto_card.dart';
import 'carrito_screen.dart';

/// Pantalla principal: catálogo de FreshMarket.
///
/// Ahora es Stateful porque tiene estado PROPIO de esta pantalla: la
/// categoría elegida y el texto de búsqueda. Eso no le importa a
/// ninguna otra pantalla, así que alcanza con setState().
///
/// El carrito, en cambio, vive afuera (en CarritoProvider) y lo
/// escuchamos con ListenableBuilder, tal como recomienda el apunte en
/// vez de usar addListener a mano.
class HomeScreen extends StatefulWidget {
  final CarritoProvider carrito;

  const HomeScreen({super.key, required this.carrito});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _todas = 'Todas';

  String _categoriaSeleccionada = _todas;
  String _busqueda = '';

  List<String> get _categorias => [
        _todas,
        ...{for (final p in catalogoFreshMarket) p.categoria},
      ];

  List<Producto> get _productosFiltrados {
    final texto = _busqueda.trim().toLowerCase();
    return catalogoFreshMarket.where((producto) {
      final coincideCategoria = _categoriaSeleccionada == _todas ||
          producto.categoria == _categoriaSeleccionada;
      final coincideTexto =
          texto.isEmpty || producto.nombre.toLowerCase().contains(texto);
      return coincideCategoria && coincideTexto;
    }).toList();
  }

  void _abrirCarrito() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarritoScreen(carrito: widget.carrito),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrito = widget.carrito;
    final productos = _productosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FreshMarket',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'El almacén de Don Ceferino',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: carrito,
            builder: (context, _) {
              return IconButton(
                tooltip: 'Ver carrito',
                onPressed: _abrirCarrito,
                icon: Badge(
                  isLabelVisible: carrito.cantidadTotal > 0,
                  label: Text('${carrito.cantidadTotal}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (texto) => setState(() => _busqueda = texto),
              decoration: InputDecoration(
                hintText: 'Buscar productos',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categorias.map((categoria) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(categoria),
                    selected: categoria == _categoriaSeleccionada,
                    onSelected: (_) {
                      setState(() => _categoriaSeleccionada = categoria);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: productos.isEmpty
                ? const _SinResultados()
                : ListenableBuilder(
                    listenable: carrito,
                    builder: (context, _) {
                      return ListView.builder(
                        // Espacio abajo para que el botón flotante no
                        // tape la última tarjeta.
                        padding: const EdgeInsets.only(top: 4, bottom: 96),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final producto = productos[index];
                          return ProductoCard(
                            producto: producto,
                            cantidadEnCarrito: carrito.cantidadDe(producto),
                            onAgregar: () => carrito.agregarProducto(producto),
                            onQuitar: () => carrito.quitarProducto(producto),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      // Atajo al carrito: solo aparece cuando hay algo cargado.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: carrito,
        builder: (context, _) {
          if (carrito.estaVacio) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _abrirCarrito,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(
              'Ver pedido · ${carrito.cantidadTotal} · '
              '${formatearPrecio(carrito.total)}',
            ),
          );
        },
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No encontramos productos con ese filtro.'),
        ],
      ),
    );
  }
}
