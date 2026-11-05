import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/ficha_producto.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/escaner_view_model.dart';

/// Sección del dueño: "Cargar producto con una foto".
///
/// Don Ceferino no tiene que escribir nada: saca la foto, la IA arma la
/// etiqueta y él solo revisa el precio y toca "Guardar producto".
class EscanerScreen extends StatelessWidget {
  const EscanerScreen({super.key, required this.viewModel});

  final EscanerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cargar producto')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.paso) {
          PasoEscaner.inicio => _Inicio(viewModel: viewModel),
          PasoEscaner.analizando => _ConFoto(
              foto: viewModel.foto,
              child: const VistaCargando(
                texto: 'Mirando la foto para armar la etiqueta...',
              ),
            ),
          PasoEscaner.revisando => _Revision(viewModel: viewModel),
          PasoEscaner.guardando =>
            const VistaCargando(texto: 'Guardando en el catálogo...'),
          PasoEscaner.guardado => VistaMensaje(
              icono: Icons.check_circle,
              titulo: 'Listo: "${viewModel.ultimoGuardado}" '
                  'ya está a la venta.',
              textoBoton: 'Cargar otro producto',
              onBoton: viewModel.empezarDeNuevo,
            ),
          PasoEscaner.error => VistaMensaje.error(
              titulo: 'No pudimos leer la foto.',
              onReintentar: viewModel.empezarDeNuevo,
            ),
        },
      ),
    );
  }
}

class _Inicio extends StatelessWidget {
  const _Inicio({required this.viewModel});

  final EscanerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.photo_camera, size: 96, color: tema.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Sacale una foto al producto',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'La app reconoce qué es y arma la etiqueta sola. '
          'Vos solo revisás el precio.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: viewModel.sacarFoto,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Sacar foto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => viewModel.sacarFoto(deGaleria: true),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Elegir una foto guardada'),
        ),
      ],
    );
  }
}

class _ConFoto extends StatelessWidget {
  const _ConFoto({required this.foto, required this.child});

  final Uint8List? foto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VistaFoto(foto: foto),
        Expanded(child: child),
      ],
    );
  }
}

class _VistaFoto extends StatelessWidget {
  const _VistaFoto({required this.foto});

  final Uint8List? foto;

  @override
  Widget build(BuildContext context) {
    final foto = this.foto;
    final colores = Theme.of(context).colorScheme;
    final sinImagen = Icon(Icons.image, size: 64, color: colores.outline);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          color: colores.surfaceContainerHigh,
          alignment: Alignment.center,
          child: foto == null
              ? sinImagen
              : Image.memory(
                  foto,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => sinImagen,
                ),
        ),
      ),
    );
  }
}

class _Revision extends StatelessWidget {
  const _Revision({required this.viewModel});

  static const _categorias = [
    'Almacén',
    'Lácteos',
    'Panadería',
    'Verdulería',
    'Bebidas',
    'Limpieza',
    'Otros',
  ];

  final EscanerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ficha = viewModel.ficha!;
    final tema = Theme.of(context);
    final categorias = {..._categorias, ficha.categoria};

    // La key hace que los campos se reinicien con cada foto nueva.
    return ListView(
      key: ObjectKey(viewModel.foto),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _VistaFoto(foto: viewModel.foto),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Revisá la etiqueta',
                style: tema.textTheme.titleLarge,
              ),
              const Text('Podés cambiar cualquier dato antes de guardar.'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: ficha.nombre,
                onChanged: viewModel.cambiarNombre,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _precioComoTexto(ficha),
                onChanged: viewModel.cambiarPrecio,
                keyboardType: TextInputType.number,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                  helperText: 'Es un precio sugerido: poné el tuyo.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Categoría', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final categoria in categorias)
                    ChoiceChip(
                      label:
                          Text(categoria, style: const TextStyle(fontSize: 16)),
                      selected: categoria == ficha.categoria,
                      onSelected: (_) => viewModel.cambiarCategoria(categoria),
                    ),
                ],
              ),
              if (ficha.descripcion.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(ficha.descripcion, style: tema.textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: viewModel.puedeGuardar ? viewModel.guardar : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Guardar producto'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: viewModel.empezarDeNuevo,
                icon: const Icon(Icons.replay),
                label: const Text('Sacar otra foto'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _precioComoTexto(FichaProducto ficha) =>
      ficha.precio > 0 ? ficha.precio.round().toString() : '';
}
