import 'package:geolocator/geolocator.dart';

import '../../domain/models/permiso_ubicacion.dart';
import '../../domain/models/posicion.dart';

export '../../domain/models/permiso_ubicacion.dart';

/// El GPS del celular: lo usan el repartidor (para que lo sigan en el
/// mapa) y el cliente (botón "Usar mi ubicación" al marcar su casa).
abstract interface class UbicacionService {
  Future<PermisoUbicacion> pedirPermiso();

  /// Dónde está el celular ahora. Null si no hay permiso o el GPS está
  /// apagado.
  Future<Posicion?> posicionActual();

  /// Emite una posición cada vez que el celular se mueve.
  Stream<Posicion> seguir();
}

class UbicacionServiceGeolocator implements UbicacionService {
  const UbicacionServiceGeolocator();

  // No hace falta avisar cada paso: alcanza con cada 10 metros.
  static const _metrosEntreAvisos = 10;
  static const _limiteGps = Duration(seconds: 15);

  @override
  Future<PermisoUbicacion> pedirPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermisoUbicacion.gpsApagado;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    final concedido = permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse;
    return concedido ? PermisoUbicacion.concedido : PermisoUbicacion.denegado;
  }

  @override
  Future<Posicion?> posicionActual() async {
    if (await pedirPermiso() != PermisoUbicacion.concedido) return null;
    final punto = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _limiteGps,
      ),
    );
    return Posicion(latitud: punto.latitude, longitud: punto.longitude);
  }

  @override
  Stream<Posicion> seguir() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _metrosEntreAvisos,
      ),
    ).map(
      (punto) => Posicion(latitud: punto.latitude, longitud: punto.longitude),
    );
  }
}
