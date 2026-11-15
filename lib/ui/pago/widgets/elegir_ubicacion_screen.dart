import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/posicion.dart';
import '../view_models/elegir_ubicacion_view_model.dart';

/// Mapa para marcar dónde hay que llevar el pedido.
///
/// Se toca el mapa (o "Usar mi ubicación"), aparece la dirección de ese
/// punto y con "Es acá" vuelve a la pantalla de pago con la dirección ya
/// escrita. Devuelve una `UbicacionEntrega`.
///
/// Es dueña de su [viewModel]: lo descarta al cerrarse.
class ElegirUbicacionScreen extends StatefulWidget {
  const ElegirUbicacionScreen({super.key, required this.viewModel});

  final ElegirUbicacionViewModel viewModel;

  @override
  State<ElegirUbicacionScreen> createState() => _ElegirUbicacionScreenState();
}

class _ElegirUbicacionScreenState extends State<ElegirUbicacionScreen> {
  // Centro de la Ciudad de Mendoza, donde está el almacén.
  static const _centro = LatLng(-32.8895, -68.8458);
  static const _zoom = 16.0;

  final _mapa = MapController();
  Posicion? _ultimoPunto;

  ElegirUbicacionViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _ultimoPunto = _viewModel.punto;
    _viewModel.addListener(_centrarSiCambioElPunto);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_centrarSiCambioElPunto);
    _viewModel.dispose();
    _mapa.dispose();
    super.dispose();
  }

  // Si el punto vino del GPS, el mapa se mueve hasta ahí. Si vino de un
  // toque, ya está a la vista y moverlo solo marearía.
  void _centrarSiCambioElPunto() {
    final punto = _viewModel.punto;
    if (punto == null || punto == _ultimoPunto) return;
    _ultimoPunto = punto;
    _mapa.move(_aLatLng(punto), _mapa.camera.zoom);
  }

  void _alTocar(LatLng punto) {
    final tocado = Posicion(latitud: punto.latitude, longitud: punto.longitude);
    _ultimoPunto = tocado;
    _viewModel.marcar(tocado);
  }

  @override
  Widget build(BuildContext context) {
    final inicial = _viewModel.punto;

    return Scaffold(
      appBar: AppBar(title: const Text('Tocá dónde vivís')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: inicial == null ? _centro : _aLatLng(inicial),
              initialZoom: _zoom,
              onTap: (_, punto) => _alTocar(punto),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.freshmarket.freshmarket_app',
              ),
              ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  final punto = _viewModel.punto;
                  if (punto == null) return const SizedBox.shrink();
                  return MarkerLayer(
                    markers: [
                      Marker(
                        point: _aLatLng(punto),
                        width: 56,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          size: 52,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => FloatingActionButton.extended(
                heroTag: null,
                onPressed:
                    _viewModel.buscandoGps ? null : _viewModel.usarMiUbicacion,
                icon: _viewModel.buscandoGps
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _PanelDireccion(viewModel: _viewModel),
      ),
    );
  }

  LatLng _aLatLng(Posicion posicion) =>
      LatLng(posicion.latitud, posicion.longitud);
}

/// Abajo del mapa: la dirección encontrada y el botón para confirmar.
class _PanelDireccion extends StatelessWidget {
  const _PanelDireccion({required this.viewModel});

  final ElegirUbicacionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (icono, texto) = switch (viewModel.estado) {
      EstadoUbicacion.sinMarcar => (
          Icons.touch_app,
          'Tocá el mapa en el lugar de tu casa.',
        ),
      EstadoUbicacion.buscandoDireccion => (
          Icons.search,
          'Buscando la dirección...',
        ),
      EstadoUbicacion.conDireccion => (Icons.home, viewModel.direccion),
      EstadoUbicacion.sinCalle => (
          Icons.edit_location_alt,
          'No encontramos la calle de ese punto. '
              'La podés escribir en el paso siguiente.',
        ),
      EstadoUbicacion.error => (
          Icons.wifi_off,
          'No pudimos buscar la dirección. '
              'La podés escribir en el paso siguiente.',
        ),
    };
    final resultado = viewModel.resultado;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border(
            top: BorderSide(color: tema.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewModel.sinGps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No pudimos usar tu ubicación. Revisá que el GPS esté '
                  'prendido, o tocá el mapa.',
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ),
            Row(
              children: [
                Icon(icono, size: 32, color: tema.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texto, style: tema.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: resultado == null
                  ? null
                  : () => Navigator.pop(context, resultado),
              icon: const Icon(Icons.check),
              label: Text(resultado == null ? 'Tocá el mapa' : 'Es acá'),
            ),
          ],
        ),
      ),
    );
  }
}
