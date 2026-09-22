import 'package:flutter/material.dart';
import '../providers/carrito_provider.dart';
import 'seguimiento_screen.dart';

enum MetodoPago { tarjeta, mercadoPago }

/// Pantalla para elegir cómo se paga el pedido.
///
/// Don Ceferino pidió poder cobrar "con tarjeta o Mercado Pago". Acá
/// el pago está mockeado (no hay integración real con una pasarela
/// de pago) — eso queda para otro módulo/materia de la carrera.
class MetodoPagoScreen extends StatefulWidget {
  final CarritoProvider carrito;

  const MetodoPagoScreen({super.key, required this.carrito});

  @override
  State<MetodoPagoScreen> createState() => _MetodoPagoScreenState();
}

class _MetodoPagoScreenState extends State<MetodoPagoScreen> {
  MetodoPago _metodoSeleccionado = MetodoPago.tarjeta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Método de pago')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total a pagar: \$${widget.carrito.total.toStringAsFixed(0)}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SegmentedButton<MetodoPago>(
              segments: const [
                ButtonSegment(
                  value: MetodoPago.tarjeta,
                  label: Text('Tarjeta'),
                  icon: Icon(Icons.credit_card),
                ),
                ButtonSegment(
                  value: MetodoPago.mercadoPago,
                  label: Text('Mercado Pago'),
                  icon: Icon(Icons.account_balance_wallet),
                ),
              ],
              selected: {_metodoSeleccionado},
              // setState() acá porque este dato solo importa a ESTA
              // pantalla, no hace falta un ChangeNotifier para esto.
              onSelectionChanged: (nuevaSeleccion) {
                setState(() {
                  _metodoSeleccionado = nuevaSeleccion.first;
                });
              },
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final carrito = widget.carrito;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeguimientoScreen(carrito: carrito),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Pagar y confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
