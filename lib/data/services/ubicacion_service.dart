import 'package:geolocator/geolocator.dart';

import '../../domain/models/posicion.dart';

enum PermisoUbicacion { concedido, denegado, gpsApagado }

/// El GPS del celular del repartidor.
abstract interface class UbicacionService {
  Future<PermisoUbicacion> pedirPermiso();

  /// Emite una posición cada vez que el celular se mueve.
  Stream<Posicion> seguir();
}

class UbicacionServiceGeolocator implements UbicacionService {
  const UbicacionServiceGeolocator();

  // No hace falta avisar cada paso: alcanza con cada 10 metros.
  static const _metrosEntreAvisos = 10;

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
