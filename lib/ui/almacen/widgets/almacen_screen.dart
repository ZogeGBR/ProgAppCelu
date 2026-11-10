import 'package:flutter/material.dart';

import '../../../domain/models/producto.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/almacen_view_model.dart';

/// Sección del dueño: cargar productos, cambiar el precio del día, marcar
/// lo que no hay y borrar.
class AlmacenScreen extends StatelessWidget {
  const AlmacenScreen({
    super.key,
    required this.viewModel,
    required this.alCargarConFoto,
    required this.alSalir,
  });

  final AlmacenViewModel viewModel;

  /// null: este celular no puede (o el servidor apagó la función). Lo
  /// decide la política `permiteCargaConFoto`; la pantalla solo obedece.
  final VoidCallback? alCargarConFoto;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi almacén'),
        actions: [
          TextButton.icon(
            onPressed: alSalir,
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.estado) {
          EstadoCarga.cargando =>
            const VistaCargando(texto: 'Cargando productos...'),
          EstadoCarga.error => VistaMensaje.error(
              titulo: 'No pudimos cargar los productos.',
              onReintentar: () => viewModel.cargar(forzar: true),
            ),
          EstadoCarga.exito => _Lista(
              viewModel: viewModel,
              alCargarConFoto: alCargarConFoto,
            ),
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.viewModel, required this.alCargarConFoto});

  final AlmacenViewModel viewModel;
  final VoidCallback? alCargarConFoto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => viewModel.cargar(forzar: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (alCargarConFoto != null) ...[
            FilledButton.icon(
              onPressed: alCargarConFoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Cargar producto con una foto'),
            ),
            const SizedBox(height: 12),
          ],
          if (viewModel.fallo)
            Card(
              color: colores.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.wifi_off_rounded),
                title: Text('No se pudo guardar el cambio. Probá otra vez.'),
              ),
            ),
          for (final producto in viewModel.productos)
            _FilaProducto(producto: producto, viewModel: viewModel),
        ],
      ),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({required this.producto, required this.viewModel});

  final Producto producto;
  final AlmacenViewModel viewModel;

  Future<void> _editarPrecio(BuildContext context) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoPrecio(producto: producto),
    );
    if (texto != null) await viewModel.cambiarPrecio(producto, texto);
  }

  Future<void> _confirmarBorrado(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Borrar "${producto.nombre}"?'),
        content: const Text('Deja de aparecer en la app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) await viewModel.eliminar(producto);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(producto.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    producto.nombre,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar ${producto.nombre}',
                  onPressed: () => _confirmarBorrado(context),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _editarPrecio(context),
              icon: const Icon(Icons.edit),
              label: Text('Precio: ${formatearPrecio(producto.precio)}'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(producto.disponible ? 'Hay' : 'No hay'),
              value: producto.disponible,
              onChanged: (valor) =>
                  viewModel.cambiarDisponible(producto, valor),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoPrecio extends StatefulWidget {
  const _DialogoPrecio({required this.producto});

  final Producto producto;

  @override
  State<_DialogoPrecio> createState() => _DialogoPrecioState();
}

class _DialogoPrecioState extends State<_DialogoPrecio> {
  late final _texto = TextEditingController(
    text: widget.producto.precio.round().toString(),
  );

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.producto.nombre),
      content: TextField(
        controller: _texto,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          labelText: 'Precio de hoy',
          prefixText: '\$ ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _texto.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
