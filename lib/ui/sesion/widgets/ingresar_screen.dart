import 'package:flutter/material.dart';

import '../../core/widgets/campo_clave.dart';
import '../view_models/recuperar_clave_view_model.dart';
import '../view_models/sesion_view_model.dart';
import 'recuperar_clave_screen.dart';

/// Ingreso del dueño o del repartidor con su email y su contraseña.
class IngresarScreen extends StatefulWidget {
  const IngresarScreen({
    super.key,
    required this.viewModel,
    required this.crearRecuperacion,
    this.pista,
  });

  final SesionViewModel viewModel;

  /// Arma el ViewModel de "¿Olvidaste tu contraseña?" con el email escrito.
  final RecuperarClaveViewModel Function(String email) crearRecuperacion;

  /// Ayuda para el modo demo: dice qué cuentas se pueden usar.
  final String? pista;

  @override
  State<IngresarScreen> createState() => _IngresarScreenState();
}

class _IngresarScreenState extends State<IngresarScreen> {
  final _email = TextEditingController();
  final _clave = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    await widget.viewModel.ingresar(_email.text, _clave.text);
    // Después del await la pantalla puede no existir más.
    if (!mounted || !widget.viewModel.haySesion) return;
    // La barra de abajo observa la sesión y abre la sección que
    // corresponde: acá solo se cierra esta pantalla.
    Navigator.pop(context);
  }

  Future<void> _olvideMiClave() async {
    final viewModel = widget.crearRecuperacion(_email.text);
    final cambiada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecuperarClaveScreen(viewModel: viewModel),
      ),
    );
    if (!mounted || cambiada != true) return;
    _email.text = viewModel.email;
    _clave.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listo. Ya podés ingresar con tu contraseña nueva.'),
      ),
    );
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
            EstadoIngreso.datosIncorrectos =>
              'El email o la contraseña no son correctos.',
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
                'Para comprar no hace falta ninguna cuenta.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !ingresando,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CampoClave(
                controlador: _clave,
                habilitado: !ingresando,
                textoError: error,
                alEnviar: _ingresar,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: ingresando ? null : _olvideMiClave,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              if (pista != null) ...[
                Text(pista, style: tema.textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
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
