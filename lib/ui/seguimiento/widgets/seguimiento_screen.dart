import 'package:flutter/material.dart';

import '../../../domain/models/estado_pedido.dart';
import '../../avisos/view_models/avisos_view_model.dart';
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
    this.avisos,
  });

  final SeguimientoViewModel viewModel;
  final VoidCallback alIrAComprar;

  /// Para mostrar "Activá las notificaciones" si la persona no las dejó.
  final AvisosViewModel? avisos;

  @override
  Widget build(BuildContext context) {
    final avisos = this.avisos;
    return ListenableBuilder(
      // Observa a los dos: el pedido y el permiso de las notificaciones.
      listenable: Listenable.merge([viewModel, if (avisos != null) avisos]),
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
              if (viewModel.sinConexion) const _AvisoSinConexion(),
              if (avisos != null &&
                  avisos.permisoDenegado &&
                  !viewModel.entregado)
                _ActivarAvisos(alActivar: avisos.pedirPermiso),
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
                        etiqueta: 'Forma de pago',
                        valor: pedido.metodoPago.nombre,
                      ),
                      if (pedido.direccion.isNotEmpty)
                        _FilaResumen(
                          etiqueta: 'Entrega en',
                          valor: pedido.direccion,
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
            child:
                Icon(estado.icono, size: 40, color: tema.colorScheme.primary),
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
              if (!esUltima) Expanded(child: Container(width: 2, color: color)),
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

/// Sin permiso, la persona no se entera cuando sale su pedido si cierra la
/// app. Se le explica para qué sirve y se le ofrece activarlo.
class _ActivarAvisos extends StatelessWidget {
  const _ActivarAvisos({required this.alActivar});

  final Future<void> Function() alActivar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: const Text('Activá las notificaciones'),
        subtitle: const Text(
          'Así te avisamos cuando tu pedido sale y cuando llega, '
          'aunque cierres la app.',
        ),
        trailing: TextButton(
          onPressed: alActivar,
          child: const Text('Activar'),
        ),
      ),
    );
  }
}
