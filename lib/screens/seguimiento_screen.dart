import 'dart:async';
import 'package:flutter/material.dart';
import '../models/estado_pedido.dart';
import '../models/metodo_pago.dart';
import '../models/pedido.dart';
import '../utils/formato.dart';

/// Pantalla de seguimiento del pedido.
///
/// Don Ceferino pidió ver "en todo momento, como el GPS de un taxi"
/// dónde está su pedido. Como en esta etapa de la materia todavía no
/// vimos geolocalización ni mapas, lo simulamos con una línea de
/// tiempo por etapas que avanza sola con un Timer.
///
/// Recibe el Pedido ya confirmado (el carrito se vació antes de
/// llegar acá, en MetodoPagoScreen), así que no depende del carrito.
class SeguimientoScreen extends StatefulWidget {
  final Pedido pedido;

  const SeguimientoScreen({super.key, required this.pedido});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  EstadoPedido _estado = EstadoPedido.recibido;
  Timer? _timer;

  bool get _entregado => _estado == EstadoPedido.entregado;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Chequeamos mounted porque este callback es asincrónico: si la
      // pantalla ya no existe, no hay que llamar setState().
      if (!mounted) return;
      setState(() {
        _estado = _siguienteEstado(_estado);
      });
      if (_entregado) {
        timer.cancel();
      }
    });
  }

  EstadoPedido _siguienteEstado(EstadoPedido actual) {
    final siguiente = actual.index + 1;
    return siguiente < EstadoPedido.values.length
        ? EstadoPedido.values[siguiente]
        : actual;
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
    final theme = Theme.of(context);
    final pedido = widget.pedido;

    return Scaffold(
      appBar: AppBar(title: Text('Pedido #${pedido.numero}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // --- Punto de extensión ---
          // Acá, en una próxima entrega, iría un mapa real (por ej.
          // con google_maps_flutter) mostrando la ubicación en vivo
          // del repartidor (el Tobías o la Male, según Don
          // Ceferino). Por ahora usamos un ícono + progreso
          // simulado, sin tocar el resto de la pantalla.
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: CircleAvatar(
                key: ValueKey(_estado),
                radius: 56,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  _estado.icono,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(_estado),
              children: [
                Text(
                  _estado.titulo,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _estado.descripcion,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _estado.progreso),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(value: value, minHeight: 10);
              },
            ),
          ),
          const SizedBox(height: 24),
          for (final etapa in EstadoPedido.values)
            _EtapaTimeline(
              etapa: etapa,
              completada: etapa.index <= _estado.index,
              esUltima: etapa == EstadoPedido.values.last,
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FilaResumen(
                    etiqueta: 'Productos',
                    valor: '${pedido.cantidadProductos}',
                  ),
                  _FilaResumen(
                    etiqueta: 'Pagado con',
                    valor: pedido.metodoPago.nombre,
                  ),
                  _FilaResumen(
                    etiqueta: 'Total',
                    valor: formatearPrecio(pedido.total),
                    destacado: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _entregado
              ? FilledButton.icon(
                  // El catálogo quedó justo debajo (ver MetodoPagoScreen),
                  // así que alcanza con un pop.
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.storefront),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Hacer otro pedido'),
                  ),
                )
              : OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Seguir comprando'),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Un paso de la línea de tiempo: círculo + texto, unido al paso
/// siguiente por una línea vertical.
class _EtapaTimeline extends StatelessWidget {
  final EstadoPedido etapa;
  final bool completada;
  final bool esUltima;

  const _EtapaTimeline({
    required this.etapa,
    required this.completada,
    required this.esUltima,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = completada ? colorScheme.primary : colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: completada ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: completada
                    ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                    : null,
              ),
              if (!esUltima)
                Expanded(
                  child: Container(width: 2, color: color),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 20),
              child: Text(
                etapa.titulo,
                style: TextStyle(
                  fontWeight: completada ? FontWeight.bold : FontWeight.normal,
                  color: completada ? null : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;

  const _FilaResumen({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}
