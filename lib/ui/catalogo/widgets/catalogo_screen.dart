import 'package:flutter/material.dart';

import '../../carrito/view_models/carrito_view_model.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/catalogo_view_model.dart';
import 'producto_card.dart';

/// Sección "Comprar": buscador, categorías y lista de productos.
class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({
    super.key,
    required this.viewModel,
    required this.carrito,
    required this.alVerCarrito,
    this.alIngresar,
  });

  final CatalogoViewModel viewModel;
  final CarritoViewModel carrito;
  final VoidCallback alVerCarrito;

  /// Abre el ingreso del dueño o del repartidor. Null si ya ingresaron.
  final VoidCallback? alIngresar;

  @override
  Widget build(BuildContext context) {
    final alIngresar = this.alIngresar;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (alIngresar != null)
            IconButton(
              tooltip: 'Soy del almacén',
              onPressed: alIngresar,
              icon: const Icon(Icons.storefront_outlined),
            ),
        ],
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FreshMarket'),
            Text('El almacén de Don Ceferino', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([viewModel, carrito]),
        builder: (context, _) => switch (viewModel.estado) {
          EstadoCarga.cargando =>
            const VistaCargando(texto: 'Cargando productos...'),
          EstadoCarga.error => VistaMensaje.error(
              titulo: 'No pudimos cargar los productos.',
              onReintentar: () => viewModel.cargar(forzar: true),
            ),
          EstadoCarga.exito => _ListaDeProductos(
              viewModel: viewModel,
              carrito: carrito,
            ),
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: carrito,
        builder: (context, _) {
          if (carrito.estaVacio) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: alVerCarrito,
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              'Ver mi carrito · ${carrito.cantidadTotal} · '
              '${formatearPrecio(carrito.total)}',
              style: const TextStyle(fontSize: 17),
            ),
          );
        },
      ),
    );
  }
}

class _ListaDeProductos extends StatelessWidget {
  const _ListaDeProductos({required this.viewModel, required this.carrito});

  final CatalogoViewModel viewModel;
  final CarritoViewModel carrito;

  @override
  Widget build(BuildContext context) {
    final productos = viewModel.productosVisibles;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: viewModel.buscar,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: '¿Qué estás buscando?',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final categoria in viewModel.categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label:
                        Text(categoria, style: const TextStyle(fontSize: 16)),
                    selected: categoria == viewModel.categoriaElegida,
                    onSelected: (_) => viewModel.elegirCategoria(categoria),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: productos.isEmpty
              ? const VistaMensaje(
                  icono: Icons.search_off,
                  titulo: 'No encontramos productos con ese nombre.',
                  detalle: 'Probá con otra palabra o elegí "Todas".',
                )
              : RefreshIndicator(
                  onRefresh: () => viewModel.cargar(forzar: true),
                  child: ListView.builder(
                    // Espacio abajo para que el botón del carrito no
                    // tape la última tarjeta.
                    padding: const EdgeInsets.only(top: 4, bottom: 104),
                    itemCount: productos.length,
                    itemBuilder: (context, indice) {
                      final producto = productos[indice];
                      return ProductoCard(
                        producto: producto,
                        cantidadEnCarrito: carrito.cantidadDe(producto),
                        onAgregar: () => carrito.agregarProducto(producto),
                        onQuitar: () => carrito.quitarProducto(producto),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
