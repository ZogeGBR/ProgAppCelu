import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/posicion.dart';
import '../../../domain/models/recorrido.dart';

/// Mapa con la bicicleta del repartidor, el almacén y la casa del cliente.
///
/// Usa OpenStreetMap con flutter_map: es gratis y no necesita clave,
/// algo importante porque Don Ceferino no quiere pagar servicios.
///
/// Con [ruta] dibuja el camino por las calles y la bici avanza POR ese
/// camino: entre una posición y la siguiente se anima suave, siguiendo las
/// esquinas, en vez de saltar o cruzar las manzanas en diagonal. Sin ruta
/// (GPS real del repartidor) se anima en línea recta entre dos posiciones.
class MapaRepartidor extends StatefulWidget {
  const MapaRepartidor({
    super.key,
    required this.repartidor,
    this.destino,
    this.ruta = const [],
    this.duracionDelPaso = const Duration(milliseconds: 1900),
  });

  final Posicion repartidor;
  final Posicion? destino;
  final List<Posicion> ruta;

  /// Cuánto tarda la bici en ir de una posición a la siguiente. Conviene
  /// que sea apenas menos que el tiempo entre novedades.
  final Duration duracionDelPaso;

  @override
  State<MapaRepartidor> createState() => _MapaRepartidorState();
}

class _MapaRepartidorState extends State<MapaRepartidor>
    with SingleTickerProviderStateMixin {
  static const _zoomInicial = 15.0;
  static const _tamanoMarcador = 52.0;
  static const _zoomMaximo = 17.0;
  static const _margen = EdgeInsets.all(48);

  final _controlador = MapController();
  late final AnimationController _animacion;

  Recorrido? _recorrido;

  // La bici va de [_desde] a [_hasta] mientras corre la animación.
  late Posicion _desde;
  late Posicion _hasta;
  double _metrosDesde = 0;
  double _metrosHasta = 0;

  @override
  void initState() {
    super.initState();
    _animacion = AnimationController(
      vsync: this,
      duration: widget.duracionDelPaso,
    );
    _recorrido = _armarRecorrido(widget.ruta);
    _desde = widget.repartidor;
    _hasta = widget.repartidor;
    _medirTramo();
  }

  @override
  void didUpdateWidget(MapaRepartidor anterior) {
    super.didUpdateWidget(anterior);
    // Donde se ve la bici ahora (aunque la animación anterior no haya
    // terminado), medido con el camino que había hasta recién.
    final actual = _posicionActual;
    final cambioLaRuta = !listEquals(anterior.ruta, widget.ruta);
    if (cambioLaRuta) _recorrido = _armarRecorrido(widget.ruta);
    if (anterior.repartidor == widget.repartidor && !cambioLaRuta) return;

    _desde = actual;
    _hasta = widget.repartidor;
    _medirTramo();
    _animacion
      ..duration = widget.duracionDelPaso
      ..forward(from: 0);
    // Con camino, el mapa muestra todo el recorrido una vez y queda quieto
    // mientras la bici avanza; sin camino, sigue a la bici.
    if (cambioLaRuta || _recorrido == null) _encuadrar();
  }

  static Recorrido? _armarRecorrido(List<Posicion> ruta) {
    final recorrido = Recorrido(ruta);
    return recorrido.esValido ? recorrido : null;
  }

  void _medirTramo() {
    final recorrido = _recorrido;
    if (recorrido == null) return;
    _metrosDesde = recorrido.metrosHasta(_desde);
    _metrosHasta = recorrido.metrosHasta(_hasta);
    // Nunca para atrás: si la posición nueva cae antes, se queda donde está.
    if (_metrosHasta < _metrosDesde) _metrosHasta = _metrosDesde;
  }

  /// Dónde dibujar la bici en este cuadro de la animación.
  Posicion get _posicionActual {
    final t = Curves.easeInOut.transform(_animacion.value);
    final recorrido = _recorrido;
    if (recorrido != null) {
      return recorrido.puntoA(_metrosDesde + (_metrosHasta - _metrosDesde) * t);
    }
    return Posicion(
      latitud: _desde.latitud + (_hasta.latitud - _desde.latitud) * t,
      longitud: _desde.longitud + (_hasta.longitud - _desde.longitud) * t,
    );
  }

  /// Muestra todo el camino (o la bici y la casa). Null si no hay casa.
  CameraFit? get _encuadre {
    final destino = widget.destino;
    final recorrido = _recorrido;
    final puntos = recorrido != null
        ? recorrido.puntos
        : [widget.repartidor, if (destino != null) destino];
    if (puntos.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: [for (final punto in puntos) _aLatLng(punto)],
      padding: _margen,
      maxZoom: _zoomMaximo,
    );
  }

  void _encuadrar() {
    final encuadre = _encuadre;
    if (encuadre != null) {
      _controlador.fitCamera(encuadre);
    } else {
      _controlador.move(_aLatLng(widget.repartidor), _controlador.camera.zoom);
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final destino = widget.destino;
    final recorrido = _recorrido;

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
        if (recorrido != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [for (final punto in recorrido.puntos) _aLatLng(punto)],
                strokeWidth: 5,
                color: colores.primary.withValues(alpha: 0.55),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (recorrido != null)
              Marker(
                point: _aLatLng(recorrido.puntos.first),
                width: _tamanoMarcador,
                height: _tamanoMarcador,
                child: Icon(
                  Icons.storefront,
                  size: 36,
                  color: colores.secondary,
                  semanticLabel: 'Almacén',
                ),
              ),
            if (destino != null)
              Marker(
                point: _aLatLng(destino),
                width: _tamanoMarcador,
                height: _tamanoMarcador,
                child: Icon(
                  Icons.home,
                  size: 44,
                  color: colores.tertiary,
                  semanticLabel: 'Tu casa',
                ),
              ),
          ],
        ),
        // Solo la bici se redibuja en cada cuadro de la animación.
        AnimatedBuilder(
          animation: _animacion,
          builder: (context, _) => MarkerLayer(
            markers: [
              Marker(
                point: _aLatLng(_posicionActual),
                width: _tamanoMarcador,
                height: _tamanoMarcador,
                child: CircleAvatar(
                  backgroundColor: colores.primary,
                  child: Icon(Icons.pedal_bike, color: colores.onPrimary),
                ),
              ),
            ],
          ),
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  static LatLng _aLatLng(Posicion posicion) =>
      LatLng(posicion.latitud, posicion.longitud);
}
