import 'package:flutter/material.dart';

import '../../../domain/models/pedido_reparto.dart';
import '../../core/formato.dart';
import '../../core/widgets/vista_mensaje.dart';
import '../../seguimiento/widgets/mapa_repartidor.dart';
import '../view_models/reparto_view_model.dart';

/// Sección del repartidor: elige un pedido y la app manda su ubicación
/// hasta que toca "Ya lo entregué".
class RepartoScreen extends StatelessWidget {
  const RepartoScreen({
    super.key,
    required this.viewModel,
    required this.alSalir,
  });

  final RepartoViewModel viewModel;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repartir'),
        actions: [
          TextButton.icon(
            onPressed: alSalir,
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.paso) {
          PasoReparto.cargando =>
            const VistaCargando(texto: 'Buscando pedidos...'),
          PasoReparto.error => VistaMensaje.error(
              titulo: 'No pudimos traer los pedidos.',
              onReintentar: viewModel.cargar,
            ),
          PasoReparto.sinPermiso => VistaMensaje(
              icono: Icons.location_disabled,
              titulo: 'Hace falta permiso de ubicación.',
              detalle: 'Sin él, el cliente no puede ver por dónde vas. '
                  'Activalo en los ajustes del celular.',
              textoBoton: 'Volver',
              onBoton: viewModel.cargar,
            ),
          PasoReparto.gpsApagado => VistaMensaje(
              icono: Icons.location_off,
              titulo: 'El GPS está apagado.',
              detalle: 'Prendelo y probá otra vez.',
              textoBoton: 'Volver',
              onBoton: viewModel.cargar,
            ),
          PasoReparto.eligiendo => _ListaPedidos(viewModel: viewModel),
          PasoReparto.repartiendo => _Repartiendo(viewModel: viewModel),
        },
      ),
    );
  }
}

class _ListaPedidos extends StatelessWidget {
  const _ListaPedidos({required this.viewModel});

  final RepartoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.pedidos.isEmpty) {
      return VistaMensaje(
        icono: Icons.pedal_bike,
        titulo: 'No hay pedidos para llevar.',
        textoBoton: 'Actualizar',
        onBoton: viewModel.cargar,
      );
    }
    return RefreshIndicator(
      onRefresh: viewModel.cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final pedido in viewModel.pedidos)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DatosPedido(pedido: pedido),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => viewModel.empezar(pedido),
                      icon: const Icon(Icons.pedal_bike),
                      label: const Text('Salir a repartir'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DatosPedido extends StatelessWidget {
  const _DatosPedido({required this.pedido});

  final PedidoReparto pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pedido #${pedido.numero}', style: tema.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(pedido.direccion, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final producto in pedido.productos) Text(producto),
        const SizedBox(height: 8),
        Text(
          pedido.hayQueCobrar
              ? 'Cobrar ${formatearPrecio(pedido.total)} en efectivo'
              : 'Ya está pagado',
          style: tema.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: pedido.hayQueCobrar ? tema.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

class _Repartiendo extends StatelessWidget {
  const _Repartiendo({required this.viewModel});

  final RepartoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final pedido = viewModel.actual;
    if (pedido == null) return const SizedBox.shrink();

    final colores = Theme.of(context).colorScheme;
    final posicion = viewModel.posicion;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DatosPedido(pedido: pedido),
        const SizedBox(height: 16),
        if (viewModel.sinConexion)
          Card(
            color: colores.errorContainer,
            child: const ListTile(
              leading: Icon(Icons.wifi_off_rounded),
              title: Text('Sin señal. Seguimos intentando.'),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: posicion == null
                ? const VistaCargando(texto: 'Buscando tu ubicación...')
                : MapaRepartidor(
                    repartidor: posicion,
                    destino: pedido.destino,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Dejá la app abierta: si se cierra, el cliente deja de verte.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: viewModel.entregando ? null : viewModel.entregar,
          icon: const Icon(Icons.check_circle),
          label: const Text('Ya lo entregué'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: viewModel.entregando ? null : viewModel.dejarDeRepartir,
          child: const Text('Volver a la lista'),
        ),
      ],
    );
  }
}
