import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/posicion.dart';

/// Mapa con la bicicleta del repartidor y la casa del cliente.
///
/// Usa OpenStreetMap con flutter_map: es gratis y no necesita clave,
/// algo importante porque Don Ceferino no quiere pagar servicios.
/// Cada vez que llega una posición nueva, el mapa se acomoda para que se
/// vean la bici y la casa juntas.
class MapaRepartidor extends StatefulWidget {
  const MapaRepartidor({
    super.key,
    required this.repartidor,
    this.destino,
  });

  final Posicion repartidor;
  final Posicion? destino;

  @override
  State<MapaRepartidor> createState() => _MapaRepartidorState();
}

class _MapaRepartidorState extends State<MapaRepartidor> {
  static const _zoomInicial = 15.0;
  static const _tamanoMarcador = 52.0;
  static const _zoomMaximo = 17.0;
  static const _margen = EdgeInsets.all(56);

  final _controlador = MapController();

  @override
  void didUpdateWidget(MapaRepartidor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.repartidor == widget.repartidor) return;

    final encuadre = _encuadre;
    if (encuadre != null) {
      _controlador.fitCamera(encuadre);
    } else {
      _controlador.move(_aLatLng(widget.repartidor), _controlador.camera.zoom);
    }
  }

  /// Muestra la bici y la casa. Null si todavía no se sabe dónde es la casa.
  CameraFit? get _encuadre {
    final destino = widget.destino;
    if (destino == null) return null;
    return CameraFit.coordinates(
      coordinates: [_aLatLng(widget.repartidor), _aLatLng(destino)],
      padding: _margen,
      maxZoom: _zoomMaximo,
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final destino = widget.destino;

    return FlutterMap(
      mapController: _controlador,
      options: MapOptions(
        initialCenter: _aLatLng(widget.repartidor),
        initialZoom: _zoomInicial,
        initialCameraFit: _encuadre,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.freshmarket.freshmarket_app',
        ),
        MarkerLayer(
          markers: [
            if (destino != null)
              Marker(
                point: _aLatLng(destino),
                width: _tamanoMarcador,
                height: _tamanoMarcador,
                child: Icon(Icons.home, size: 44, color: colores.tertiary),
              ),
            Marker(
              point: _aLatLng(widget.repartidor),
              width: _tamanoMarcador,
              height: _tamanoMarcador,
              child: CircleAvatar(
                backgroundColor: colores.primary,
                child: Icon(Icons.pedal_bike, color: colores.onPrimary),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  LatLng _aLatLng(Posicion posicion) =>
      LatLng(posicion.latitud, posicion.longitud);
}
