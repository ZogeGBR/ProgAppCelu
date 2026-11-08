import 'package:flutter/material.dart';

import '../../core/widgets/campo_clave.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/recuperar_clave_view_model.dart';

/// "¿Olvidaste tu contraseña?": email → código que llega por correo →
/// contraseña nueva. Cierra devolviendo `true` si se cambió.
///
/// Es dueña de su [viewModel]: lo descarta al cerrarse.
class RecuperarClaveScreen extends StatefulWidget {
  const RecuperarClaveScreen({super.key, required this.viewModel});

  final RecuperarClaveViewModel viewModel;

  @override
  State<RecuperarClaveScreen> createState() => _RecuperarClaveScreenState();
}

class _RecuperarClaveScreenState extends State<RecuperarClaveScreen> {
  late final _email = TextEditingController(text: widget.viewModel.email);
  final _codigo = TextEditingController();
  final _clave = TextEditingController();
  final _repetida = TextEditingController();

  RecuperarClaveViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _clave.dispose();
    _repetida.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _enviarCodigo() => _viewModel.enviarCodigo(_email.text);

  void _cambiarClave() => _viewModel.cambiarClave(
        codigo: _codigo.text,
        claveNueva: _clave.text,
        repetida: _repetida.text,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => switch (_viewModel.paso) {
          PasoRecuperacion.pedirEmail => _PedirEmail(
              email: _email,
              error: _viewModel.error,
              alEnviar: _enviarCodigo,
            ),
          PasoRecuperacion.enviandoCodigo =>
            const VistaCargando(texto: 'Mandando el código a tu email...'),
          PasoRecuperacion.cambiarClave => _CambiarClave(
              email: _viewModel.email,
              codigo: _codigo,
              clave: _clave,
              repetida: _repetida,
              error: _viewModel.error,
              alGuardar: _cambiarClave,
              alPedirOtro: _viewModel.volverAPedirCodigo,
            ),
          PasoRecuperacion.guardando =>
            const VistaCargando(texto: 'Guardando tu contraseña nueva...'),
          PasoRecuperacion.lista => VistaMensaje(
              icono: Icons.check_circle,
              titulo: '¡Listo! Tu contraseña cambió.',
              textoBoton: 'Volver a ingresar',
              onBoton: () => Navigator.pop(context, true),
            ),
        },
      ),
    );
  }
}

/// Texto de cada error, en palabras simples.
String? _mensajeDe(ErrorRecuperacion error) => switch (error) {
      ErrorRecuperacion.ninguno => null,
      ErrorRecuperacion.emailInvalido => 'Revisá el email: falta algo.',
      ErrorRecuperacion.codigoInvalido =>
        'El código tiene ${RecuperarClaveViewModel.largoCodigo} números.',
      ErrorRecuperacion.claveCorta => 'Tiene que tener al menos '
          '${RecuperarClaveViewModel.largoMinimoClave} caracteres.',
      ErrorRecuperacion.clavesDistintas =>
        'Las dos contraseñas no son iguales.',
      ErrorRecuperacion.codigoIncorrecto =>
        'El código no es correcto o ya venció.',
      ErrorRecuperacion.sinConexion =>
        'No pudimos conectarnos. Revisá tu internet y probá otra vez.',
    };

class _PedirEmail extends StatelessWidget {
  const _PedirEmail({
    required this.email,
    required this.error,
    required this.alEnviar,
  });

  final TextEditingController email;
  final ErrorRecuperacion error;
  final VoidCallback alEnviar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.mark_email_read_outlined,
            size: 80, color: tema.colorScheme.primary),
        const SizedBox(height: 16),
        const Text(
          'Escribí el email de tu cuenta y te mandamos un código de 6 números.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onSubmitted: (_) => alEnviar(),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline),
            border: const OutlineInputBorder(),
            errorText: _mensajeDe(error),
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: alEnviar,
          icon: const Icon(Icons.send),
          label: const Text('Mandarme el código'),
        ),
      ],
    );
  }
}

class _CambiarClave extends StatelessWidget {
  const _CambiarClave({
    required this.email,
    required this.codigo,
    required this.clave,
    required this.repetida,
    required this.error,
    required this.alGuardar,
    required this.alPedirOtro,
  });

  final String email;
  final TextEditingController codigo;
  final TextEditingController clave;
  final TextEditingController repetida;
  final ErrorRecuperacion error;
  final VoidCallback alGuardar;
  final VoidCallback alPedirOtro;

  @override
  Widget build(BuildContext context) {
    final errorCodigo = error == ErrorRecuperacion.codigoInvalido ||
            error == ErrorRecuperacion.codigoIncorrecto
        ? _mensajeDe(error)
        : null;
    final errorClave = error == ErrorRecuperacion.claveCorta ||
            error == ErrorRecuperacion.clavesDistintas ||
            error == ErrorRecuperacion.sinConexion
        ? _mensajeDe(error)
        : null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Si $email tiene una cuenta, te llegó un código. '
          'Revisá también la carpeta de spam.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codigo,
          keyboardType: TextInputType.number,
          maxLength: RecuperarClaveViewModel.largoCodigo,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: InputDecoration(
            labelText: 'Código',
            prefixIcon: const Icon(Icons.pin_outlined),
            border: const OutlineInputBorder(),
            errorText: errorCodigo,
          ),
        ),
        const SizedBox(height: 8),
        CampoClave(
          controlador: clave,
          etiqueta: 'Contraseña nueva',
          ayuda: 'Al menos ${RecuperarClaveViewModel.largoMinimoClave} '
              'caracteres.',
          accion: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        CampoClave(
          controlador: repetida,
          etiqueta: 'Repetí la contraseña nueva',
          textoError: errorClave,
          alEnviar: alGuardar,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: alGuardar,
          icon: const Icon(Icons.save),
          label: const Text('Guardar contraseña nueva'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: alPedirOtro,
          child: const Text('No me llegó: pedir otro código'),
        ),
      ],
    );
  }
}
