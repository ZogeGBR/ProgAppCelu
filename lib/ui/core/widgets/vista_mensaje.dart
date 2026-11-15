import 'package:flutter/material.dart';

/// Pantalla de "pasó algo" con un ícono grande, un texto simple y,
/// opcionalmente, un botón para seguir (reintentar, ir al catálogo...).
///
/// Se usa para cargas, errores y estados vacíos, así todas las
/// pantallas hablan igual.
class VistaMensaje extends StatelessWidget {
  const VistaMensaje({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.textoBoton,
    this.onBoton,
  });

  /// Mensaje estándar de error con botón "Reintentar".
  const VistaMensaje.error({
    super.key,
    required this.titulo,
    required VoidCallback onReintentar,
  })  : icono = Icons.wifi_off_rounded,
        detalle = 'Revisá tu conexión a internet y probá otra vez.',
        textoBoton = 'Reintentar',
        onBoton = onReintentar;

  final IconData icono;
  final String titulo;
  final String? detalle;
  final String? textoBoton;
  final VoidCallback? onBoton;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final detalle = this.detalle;
    final textoBoton = this.textoBoton;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 80, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge,
            ),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(detalle, textAlign: TextAlign.center),
            ],
            if (textoBoton != null && onBoton != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onBoton, child: Text(textoBoton)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Indicador de carga con un texto que dice qué se está esperando.
class VistaCargando extends StatelessWidget {
  const VistaCargando({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
