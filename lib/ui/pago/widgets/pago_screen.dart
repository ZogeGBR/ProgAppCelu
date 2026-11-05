import 'package:flutter/material.dart';

import '../../../domain/models/item_carrito.dart';
import '../../../domain/models/metodo_pago.dart';
import '../../../domain/models/posicion.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../view_models/pago_view_model.dart';
import 'elegir_ubicacion_screen.dart';
import 'metodo_pago_ui.dart';

/// Pantalla de pago con Mercado Pago (débito, crédito o dinero en cuenta).
///
/// Es dueña de su [viewModel]: lo descarta al cerrarse.
class PagoScreen extends StatefulWidget {
  const PagoScreen({
    super.key,
    required this.viewModel,
    required this.items,
    required this.total,
    required this.alVerPedido,
  });

  final PagoViewModel viewModel;
  final List<ItemCarrito> items;
  final double total;

  /// Se llama al salir de la pantalla con el pago aprobado.
  final VoidCallback alVerPedido;

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  PagoViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final paso = _viewModel.paso;
        return PopScope(
          // Mientras se procesa el pago no se puede salir con "atrás".
          canPop: !_viewModel.estaOcupado,
          onPopInvokedWithResult: (seFue, _) {
            if (seFue && paso == PasoPago.aprobado) widget.alVerPedido();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Pagar'),
              automaticallyImplyLeading: !_viewModel.estaOcupado,
            ),
            body: switch (paso) {
              PasoPago.eligiendo => _ElegirMetodo(
                  viewModel: _viewModel,
                  items: widget.items,
                  total: widget.total,
                ),
              PasoPago.abriendoMercadoPago => VistaCargando(
                  texto: _viewModel.esEfectivo
                      ? 'Confirmando tu pedido...'
                      : 'Abriendo Mercado Pago...',
                ),
              PasoPago.esperandoConfirmacion =>
                _EsperandoConfirmacion(onCancelar: _viewModel.volverAElegir),
              PasoPago.aprobado => VistaMensaje(
                  icono: Icons.check_circle,
                  titulo: _viewModel.esEfectivo
                      ? '¡Listo! Tu pedido está confirmado.'
                      : '¡Listo! Tu pago fue aprobado.',
                  detalle: _viewModel.esEfectivo
                      ? 'Pedido #${_viewModel.pedido?.numero}. Le pagás '
                          '${formatearPrecio(widget.total)} al repartidor '
                          'cuando llegue.'
                      : 'Pedido #${_viewModel.pedido?.numero}. '
                          'Ya lo estamos preparando.',
                  textoBoton: 'Ver mi pedido',
                  onBoton: () => Navigator.pop(context),
                ),
              PasoPago.rechazado => VistaMensaje(
                  icono: Icons.credit_card_off,
                  titulo: 'El pago no se aprobó.',
                  detalle: 'No se cobró nada. Podés probar con otra '
                      'tarjeta o con dinero en Mercado Pago.',
                  textoBoton: 'Probar de nuevo',
                  onBoton: _viewModel.volverAElegir,
                ),
              PasoPago.sinConfirmar => VistaMensaje(
                  icono: Icons.hourglass_bottom,
                  titulo: 'Todavía no recibimos la confirmación.',
                  detalle: 'Si ya pagaste, revisá la app de Mercado Pago. '
                      'Si no, podés intentar otra vez.',
                  textoBoton: 'Intentar otra vez',
                  onBoton: _viewModel.volverAElegir,
                ),
              PasoPago.error => VistaMensaje.error(
                  titulo: 'No pudimos conectar con Mercado Pago.',
                  onReintentar: _viewModel.volverAElegir,
                ),
            },
          ),
        );
      },
    );
  }
}

/// Escribir la dirección es obligatorio; marcarla en el mapa, no: así quien
/// no se lleva bien con los mapas también puede comprar.
class _Direccion extends StatelessWidget {
  const _Direccion({required this.viewModel});

  final PagoViewModel viewModel;

  Future<void> _marcarEnMapa(BuildContext context) async {
    final destino = await Navigator.of(context).push<Posicion>(
      MaterialPageRoute(
        builder: (_) => ElegirUbicacionScreen(inicial: viewModel.destino),
      ),
    );
    if (destino != null) viewModel.marcarDestino(destino);
  }

  @override
  Widget build(BuildContext context) {
    final marcada = viewModel.destino != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: viewModel.direccion,
          onChanged: viewModel.cambiarDireccion,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            labelText: 'Calle y número',
            hintText: 'Por ejemplo: San Martín 1234',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _marcarEnMapa(context),
          icon: Icon(marcada ? Icons.check_circle : Icons.map_outlined),
          label: Text(
            marcada ? 'Ya marcaste tu casa' : 'Marcar mi casa en el mapa',
          ),
        ),
      ],
    );
  }
}

class _ElegirMetodo extends StatelessWidget {
  const _ElegirMetodo({
    required this.viewModel,
    required this.items,
    required this.total,
  });

  final PagoViewModel viewModel;
  final List<ItemCarrito> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final metodo = viewModel.metodoElegido;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu pedido', style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final item in items)
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
                    Text('Total a pagar', style: tema.textTheme.titleMedium),
                    Text(
                      formatearPrecio(total),
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('1. ¿A dónde te lo llevamos?', style: tema.textTheme.titleMedium),
        const SizedBox(height: 12),
        _Direccion(viewModel: viewModel),
        const SizedBox(height: 24),
        Text('2. Elegí cómo querés pagar', style: tema.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final opcion in MetodoPago.values)
          _OpcionPago(
            metodo: opcion,
            elegido: opcion == metodo,
            onTap: () => viewModel.elegirMetodo(opcion),
          ),
        const SizedBox(height: 16),
        Text(
          viewModel.esEfectivo ? '3. Confirmá' : '3. Tocá pagar',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          viewModel.esEfectivo
              ? 'Te lo llevamos y le pagás al repartidor.'
              : 'Te llevamos a Mercado Pago para que pagues seguro. '
                  'Cuando termines, volvé a esta app.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: viewModel.puedePagar ? viewModel.pagar : null,
          icon: const Icon(Icons.lock_outline),
          label: Text(
            switch ((viewModel.faltaDireccion, metodo)) {
              (true, _) => 'Escribí tu dirección',
              (false, null) => 'Elegí cómo pagar',
              (false, MetodoPago.efectivo) => 'Confirmar pedido',
              (false, _) => 'Pagar ${formatearPrecio(total)}',
            },
          ),
        ),
      ],
    );
  }
}

class _OpcionPago extends StatelessWidget {
  const _OpcionPago({
    required this.metodo,
    required this.elegido,
    required this.onTap,
  });

  final MetodoPago metodo;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: elegido ? colores.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegido ? colores.primary : colores.outlineVariant,
          width: elegido ? 3 : 1,
        ),
      ),
      child: ListTile(
        minVerticalPadding: 16,
        onTap: onTap,
        leading: Icon(metodo.icono, size: 32),
        title: Text(
          metodo.nombre,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(metodo.ayuda),
        trailing: Icon(
          elegido ? Icons.radio_button_checked : Icons.radio_button_off,
          color: elegido ? colores.primary : null,
          size: 28,
        ),
      ),
    );
  }
}

class _EsperandoConfirmacion extends StatelessWidget {
  const _EsperandoConfirmacion({required this.onCancelar});

  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: VistaCargando(
              texto: 'Esperando la confirmación de Mercado Pago...\n'
                  'Cuando termines de pagar, volvé a esta app.',
            ),
          ),
          OutlinedButton(
            onPressed: onCancelar,
            child: const Text('Volver y elegir otro medio'),
          ),
        ],
      ),
    );
  }
}
