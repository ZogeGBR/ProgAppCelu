import 'posicion.dart';

/// El almacén de Don Ceferino: de acá sale siempre la bicicleta.
abstract final class Almacen {
  static const nombre = 'Almacén de Don Ceferino';
  static const direccion = 'Gutiérrez 746, Ciudad de Mendoza';

  /// Gutiérrez 746, centro de Mendoza.
  static const ubicacion = Posicion(latitud: -32.886929, longitud: -68.848384);
}
