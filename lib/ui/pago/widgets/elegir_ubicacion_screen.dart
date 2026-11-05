import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/posicion.dart';

/// Mapa para marcar dónde hay que llevar el pedido: se toca y listo.
/// Al confirmar, devuelve la [Posicion] elegida.
class ElegirUbicacionScreen extends StatefulWidget {
  const ElegirUbicacionScreen({super.key, this.inicial});

  final Posicion? inicial;

  @override
  State<ElegirUbicacionScreen> createState() => _ElegirUbicacionScreenState();
}

class _ElegirUbicacionScreenState extends State<ElegirUbicacionScreen> {
  // Centro de la Ciudad de Mendoza, donde está el almacén.
  static const _centro = LatLng(-32.8895, -68.8458);
  static const _zoom = 15.0;

  late LatLng? _elegida = widget.inicial == null
      ? null
      : LatLng(widget.inicial!.latitud, widget.inicial!.longitud);

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final elegida = _elegida;

    return Scaffold(
      appBar: AppBar(title: const Text('Tocá dónde vivís')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: elegida ?? _centro,
          initialZoom: _zoom,
          onTap: (_, punto) => setState(() => _elegida = punto),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.freshmarket.freshmarket_app',
          ),
          if (elegida != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: elegida,
                  width: 56,
                  height: 56,
                  child: Icon(Icons.home, size: 48, color: colores.tertiary),
                ),
              ],
            ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: elegida == null
                ? null
                : () => Navigator.pop(
                      context,
                      Posicion(
                        latitud: elegida.latitude,
                        longitud: elegida.longitude,
                      ),
                    ),
            icon: const Icon(Icons.check),
            label: Text(elegida == null ? 'Tocá el mapa' : 'Es acá'),
          ),
        ),
      ),
    );
  }
}
