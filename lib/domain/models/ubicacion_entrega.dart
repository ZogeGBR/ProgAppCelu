import 'posicion.dart';

/// Dónde hay que llevar el pedido: el punto que se tocó en el mapa y la
/// dirección que le corresponde ("San Martín 1234, Mendoza").
class UbicacionEntrega {
  const UbicacionEntrega({required this.posicion, required this.direccion});

  final Posicion posicion;
  final String direccion;
}
