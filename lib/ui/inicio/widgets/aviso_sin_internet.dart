import 'package:flutter/material.dart';

import '../view_models/conectividad_view_model.dart';

/// Franja arriba de todo cuando el celular se queda sin red.
///
/// Solo AVISA: si una llamada falla, cada pantalla ya muestra su propio
/// mensaje con "Reintentar" (tener red no garantiza tener internet).
class AvisoSinInternet extends StatelessWidget {
  const AvisoSinInternet({super.key, required this.viewModel});

  final ConectividadViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: viewModel.hayRed
            ? const SizedBox(width: double.infinity)
            : Material(
                color: colores.errorContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: colores.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sin internet. Revisá el Wi-Fi o los datos: '
                            'lo que elegiste queda guardado.',
                            style: TextStyle(
                              fontSize: 16,
                              color: colores.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
