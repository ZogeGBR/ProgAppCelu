import 'package:flutter/material.dart';

import '../view_models/sesion_view_model.dart';

/// Ingreso del dueño o del repartidor con su clave.
class IngresarScreen extends StatefulWidget {
  const IngresarScreen({
    super.key,
    required this.viewModel,
    required this.alIngresar,
    this.pista,
  });

  final SesionViewModel viewModel;

  /// Se llama con la pantalla ya cerrada, cuando la clave fue correcta.
  final VoidCallback alIngresar;

  /// Ayuda para el modo demo: dice qué claves se pueden usar.
  final String? pista;

  @override
  State<IngresarScreen> createState() => _IngresarScreenState();
}

class _IngresarScreenState extends State<IngresarScreen> {
  final _clave = TextEditingController();

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    await widget.viewModel.ingresar(_clave.text);
    if (!mounted || !widget.viewModel.haySesion) return;
    Navigator.pop(context);
    widget.alIngresar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pista = widget.pista;

    return Scaffold(
      appBar: AppBar(title: const Text('Soy del almacén')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final estado = widget.viewModel.estado;
          final ingresando = estado == EstadoIngreso.ingresando;
          final error = switch (estado) {
            EstadoIngreso.claveIncorrecta => 'Esa clave no es correcta.',
            EstadoIngreso.sinConexion =>
              'No pudimos conectarnos. Revisá tu internet y probá otra vez.',
            _ => null,
          };

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.storefront, size: 80, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Esto es para Don Ceferino y los repartidores. '
                'Para comprar no hace falta ninguna clave.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _clave,
                obscureText: true,
                enabled: !ingresando,
                onSubmitted: (_) => _ingresar(),
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Clave',
                  border: const OutlineInputBorder(),
                  errorText: error,
                  errorMaxLines: 2,
                ),
              ),
              if (pista != null) ...[
                const SizedBox(height: 8),
                Text(pista, style: tema.textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: ingresando ? null : _ingresar,
                icon: const Icon(Icons.login),
                label: Text(ingresando ? 'Ingresando...' : 'Ingresar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
