import 'package:flutter/material.dart';
import '../models/metodo_pago.dart';
import '../providers/carrito_provider.dart';
import '../utils/formato.dart';
import 'seguimiento_screen.dart';

/// Pantalla para elegir cómo se paga el pedido.
///
/// Don Ceferino pidió poder cobrar "con tarjeta o Mercado Pago". Acá
/// el pago está mockeado (no hay integración real con una pasarela
/// de pago) — eso queda para otro módulo/materia de la carrera. Para
/// que se sienta real, simulamos unos segundos de "procesando pago".
class MetodoPagoScreen extends StatefulWidget {
  final CarritoProvider carrito;

  const MetodoPagoScreen({super.key, required this.carrito});

  @override
  State<MetodoPagoScreen> createState() => _MetodoPagoScreenState();
}

class _MetodoPagoScreenState extends State<MetodoPagoScreen> {
  // setState() acá porque estos datos solo importan a ESTA pantalla,
  // no hace falta un ChangeNotifier para esto.
  MetodoPago _metodoSeleccionado = MetodoPago.tarjeta;
  bool _procesando = false;

  Future<void> _pagar() async {
    setState(() => _procesando = true);

    // Simulación de la pasarela de pago.
    await Future.delayed(const Duration(seconds: 2));

    // Después de un await la pantalla puede ya no existir (por ej.
    // si el usuario volvió atrás): chequeamos mounted antes de usar
    // el context.
    if (!mounted) return;

    final pedido = widget.carrito.confirmarPedido(_metodoSeleccionado);

    // Dejamos solo el catálogo debajo del seguimiento: así, al volver
    // atrás, no se cae en un carrito o una pantalla de pago vacíos.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => SeguimientoScreen(pedido: pedido),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carrito = widget.carrito;

    return PopScope(
      // Mientras "se procesa el pago" no dejamos volver atrás.
      canPop: !_procesando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Método de pago')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final item in carrito.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.cantidad} × ${item.producto.nombre}',
                              ),
                            ),
                            Text(formatearPrecio(item.subtotal)),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total a pagar',
                            style: theme.textTheme.titleMedium),
                        Text(
                          formatearPrecio(carrito.total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('¿Cómo querés pagar?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final metodo in MetodoPago.values)
              _OpcionPago(
                metodo: metodo,
                seleccionado: metodo == _metodoSeleccionado,
                onTap: _procesando
                    ? null
                    : () => setState(() => _metodoSeleccionado = metodo),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _procesando ? null : _pagar,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _procesando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Procesando pago...'),
                        ],
                      )
                    : Text(
                        'Pagar ${formatearPrecio(carrito.total)} con '
                        '${_metodoSeleccionado.nombre}',
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionPago extends StatelessWidget {
  final MetodoPago metodo;
  final bool seleccionado;
  final VoidCallback? onTap;

  const _OpcionPago({
    required this.metodo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: seleccionado ? colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionado ? colorScheme.primary : colorScheme.outlineVariant,
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(metodo.icono),
        title: Text(metodo.nombre),
        trailing: Icon(
          seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
          color: seleccionado ? colorScheme.primary : null,
        ),
      ),
    );
  }
}
