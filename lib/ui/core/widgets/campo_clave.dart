import 'package:flutter/material.dart';

/// Campo de contraseña con el botón del ojo para ver lo que se escribió.
///
/// Mostrar u ocultar es estado de la VISTA (no cambia ningún dato de la
/// app), por eso vive en el State del widget y no en un ViewModel.
class CampoClave extends StatefulWidget {
  const CampoClave({
    super.key,
    required this.controlador,
    this.etiqueta = 'Contraseña',
    this.textoError,
    this.ayuda,
    this.habilitado = true,
    this.accion = TextInputAction.done,
    this.alEnviar,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final String? textoError;
  final String? ayuda;
  final bool habilitado;
  final TextInputAction accion;
  final VoidCallback? alEnviar;

  @override
  State<CampoClave> createState() => _CampoClaveState();
}

class _CampoClaveState extends State<CampoClave> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final alEnviar = widget.alEnviar;
    return TextField(
      controller: widget.controlador,
      obscureText: !_visible,
      enabled: widget.habilitado,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.accion,
      onSubmitted: alEnviar == null ? null : (_) => alEnviar(),
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        errorText: widget.textoError,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          // 48 dp de toque, como el resto de los botones.
          iconSize: 26,
          tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
