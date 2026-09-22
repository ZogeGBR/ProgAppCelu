import 'dart:async';
import 'package:flutter/material.dart';
import '../models/estado_pedido.dart';
import '../providers/carrito_provider.dart';

/// Pantalla de seguimiento del pedido.
///
/// Don Ceferino pidió ver "en todo momento, como el GPS de un taxi"
/// dónde está su pedido. Como en esta etapa de la materia todavía no
/// vimos geolocalización ni mapas, lo simulamos con una barra de
/// progreso por etapas que avanza sola con un Timer.
class SeguimientoScreen extends StatefulWidget {
  final CarritoProvider carrito;

  const SeguimientoScreen({super.key, required this.carrito});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  EstadoPedido _estado = EstadoPedido.recibido;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // El pedido ya se confirmó y se pagó: vaciamos el carrito acá,
    // antes del primer build().
    widget.carrito.vaciarCarrito();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Chequeamos mounted porque este callback es asincrónico: si la
      // pantalla ya no existe, no hay que llamar setState().
      if (!mounted) return;
      setState(() {
        _estado = _siguienteEstado(_estado);
      });
      if (_estado == EstadoPedido.entregado) {
        timer.cancel();
      }
    });
  }

  EstadoPedido _siguienteEstado(EstadoPedido actual) {
    switch (actual) {
      case EstadoPedido.recibido:
        return EstadoPedido.enPreparacion;
      case EstadoPedido.enPreparacion:
        return EstadoPedido.enCamino;
      case EstadoPedido.enCamino:
        return EstadoPedido.entregado;
      case EstadoPedido.entregado:
        return EstadoPedido.entregado;
    }
  }

  @override
  void dispose() {
    // Si no cancelamos el Timer acá, sigue vivo en memoria (memory
    // leak) e intenta actualizar un widget que ya no existe.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento del pedido')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Punto de extensión ---
            // Acá, en una próxima entrega, iría un mapa real (por ej.
            // con google_maps_flutter) mostrando la ubicación en vivo
            // del repartidor (el Tobías o la Male, según Don
            // Ceferino). Por ahora usamos un ícono + progreso
            // simulado, sin tocar el resto de la pantalla.
            Icon(
              _estado == EstadoPedido.enCamino
                  ? Icons.delivery_dining
                  : _estado == EstadoPedido.entregado
                      ? Icons.check_circle
                      : Icons.storefront,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _estado.titulo,
                key: ValueKey(_estado),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _estado.descripcion,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _estado.progreso),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
