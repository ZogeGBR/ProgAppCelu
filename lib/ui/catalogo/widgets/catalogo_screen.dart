import 'package:flutter/material.dart';

import '../../../domain/models/producto.dart';
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

  /// Desde este ancho (tablet, o celular acostado grande) los productos se
  /// muestran en grilla. 840 es el corte "expandido" de Material 3.
  static const _anchoParaGrilla = 840.0;
  static const _anchoMaximoTarjeta = 420.0;
  static const _altoTarjeta = 210.0;

  // Espacio abajo para que el botón del carrito no tape la última tarjeta.
  static const _relleno = EdgeInsets.only(top: 4, bottom: 104);

  final CatalogoViewModel viewModel;
  final CarritoViewModel carrito;

  Widget _tarjeta(BuildContext context, Producto producto) => ProductoCard(
        producto: producto,
        cantidadEnCarrito: carrito.cantidadDe(producto),
        onAgregar: () => carrito.agregarProducto(producto),
        onQuitar: () => carrito.quitarProducto(producto),
        onVerDetalle: () => _mostrarDetalle(context, producto),
      );

  Widget _lista(BuildContext context, List<Producto> productos) =>
      ListView.builder(
        padding: _relleno,
        itemCount: productos.length,
        itemBuilder: (context, indice) => _tarjeta(context, productos[indice]),
      );

  Widget _grilla(BuildContext context, List<Producto> productos) =>
      GridView.builder(
        padding: _relleno,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _anchoMaximoTarjeta,
          mainAxisExtent: _altoTarjeta,
        ),
        itemCount: productos.length,
        itemBuilder: (context, indice) => _tarjeta(context, productos[indice]),
      );

  /// Hoja de abajo con el detalle del producto. Se abre tocando la tarjeta
  /// o manteniéndola apretada (gesto), y se cierra deslizando hacia abajo.
  void _mostrarDetalle(BuildContext context, Producto producto) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => _DetalleProducto(
        producto: producto,
        alAgregar: () {
          carrito.agregarProducto(producto);
          Navigator.pop(contexto);
        },
      ),
    );
  }

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
                  // Diseño adaptativo: decide según el ESPACIO que tiene
                  // (no según si es "tablet"), así también sirve con el
                  // celular acostado o la pantalla partida.
                  child: LayoutBuilder(
                    builder: (context, espacio) =>
                        espacio.maxWidth >= _anchoParaGrilla
                            ? _grilla(context, productos)
                            : _lista(context, productos),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DetalleProducto extends StatelessWidget {
  const _DetalleProducto({required this.producto, required this.alAgregar});

  final Producto producto;
  final VoidCallback alAgregar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              producto.emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 8),
            Text(
              producto.nombre,
              textAlign: TextAlign.center,
              style: tema.textTheme.headlineSmall,
            ),
            Text(
              producto.categoria,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
            if (producto.descripcion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(producto.descripcion, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            Text(
              formatearPrecio(producto.precio),
              textAlign: TextAlign.center,
              style: tema.textTheme.headlineMedium?.copyWith(
                color: tema.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (producto.disponible)
              FilledButton.icon(
                onPressed: alAgregar,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar al carrito'),
              )
            else
              const Text(
                'Hoy no hay. Probá mañana.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
