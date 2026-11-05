import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../../pago/widgets/metodo_pago_ui.dart';
import '../view_models/seguimiento_view_model.dart';
import 'estado_pedido_ui.dart';
import 'mapa_repartidor.dart';

/// Sección "Mi pedido": etapa actual, mapa del repartidor y resumen.
class SeguimientoScreen extends StatelessWidget {
  const SeguimientoScreen({
    super.key,
    required this.viewModel,
    required this.alIrAComprar,
  });

  final SeguimientoViewModel viewModel;
  final VoidCallback alIrAComprar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final pedido = viewModel.pedido;
        if (pedido == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi pedido')),
            body: VistaMensaje(
              icono: Icons.receipt_long_outlined,
              titulo: 'Todavía no hiciste ningún pedido.',
              detalle: 'Cuando pagues, acá vas a ver por dónde va.',
              textoBoton: 'Ir a comprar',
              onBoton: alIrAComprar,
            ),
          );
        }

        final tema = Theme.of(context);
        final posicion = viewModel.posicionRepartidor;
        final minutos = viewModel.minutosEstimados;

        return Scaffold(
          appBar: AppBar(title: Text('Pedido #${pedido.numero}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (viewModel.sinConexion)
                const _AvisoSinConexion(),
              _EtapaActual(estado: viewModel.estado),
              if (viewModel.mostrarMapa && posicion != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 280,
                    child: MapaRepartidor(
                      repartidor: posicion,
                      destino: viewModel.destino,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    '${viewModel.nombreRepartidor ?? 'El repartidor'} '
                        'viene en bici',
                    if (minutos != null) 'llega en unos $minutos min',
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 16),
              for (final etapa in EstadoPedido.values)
                _EtapaLinea(
                  etapa: etapa,
                  completada: etapa.index <= viewModel.estado.index,
                  esUltima: etapa == EstadoPedido.values.last,
                ),
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
          bottomNavigationBar: viewModel.entregado
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () {
                        viewModel.terminar();
                        alIrAComprar();
                      },
                      icon: const Icon(Icons.storefront),
                      label: const Text('Hacer otro pedido'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _EtapaActual extends StatelessWidget {
  const _EtapaActual({required this.estado});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Row(
        key: ValueKey(estado),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: tema.colorScheme.primaryContainer,
            child: Icon(estado.icono, size: 40, color: tema.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estado.titulo,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(estado.descripcion),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      color: colores.errorContainer,
      child: ListTile(
        leading: Icon(Icons.wifi_off, color: colores.onErrorContainer),
        title: Text(
          'Sin conexión. Seguimos intentando...',
          style: TextStyle(color: colores.onErrorContainer),
        ),
      ),
    );
  }
}

/// Un paso de la línea de tiempo: círculo + texto, unido al siguiente
/// por una línea vertical.
class _EtapaLinea extends StatelessWidget {
  const _EtapaLinea({
    required this.etapa,
    required this.completada,
    required this.esUltima,
  });

  final EstadoPedido etapa;
  final bool completada;
  final bool esUltima;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final color = completada ? colores.primary : colores.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: completada ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: completada
                    ? Icon(Icons.check, size: 18, color: colores.onPrimary)
                    : null,
              ),
              if (!esUltima)
                Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 20),
              child: Text(
                etapa.titulo,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: completada ? FontWeight.bold : FontWeight.normal,
                  color: completada ? null : colores.onSurfaceVariant,
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
  const _FilaResumen({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )
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
