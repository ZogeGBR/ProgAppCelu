/// Un punto en el mapa (latitud y longitud en grados).
class Posicion {
  const Posicion({required this.latitud, required this.longitud});

  factory Posicion.fromJson(Map<String, dynamic> json) => Posicion(
        latitud: (json['lat'] as num).toDouble(),
        longitud: (json['lng'] as num).toDouble(),
      );

  final double latitud;
  final double longitud;

  @override
  bool operator ==(Object other) =>
      other is Posicion &&
      other.latitud == latitud &&
      other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);
}
