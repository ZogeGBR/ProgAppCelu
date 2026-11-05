/// Un producto del almacén de Don Ceferino, con su precio del día.
///
/// Es un dato puro del dominio: no sabe de red ni de pantallas. Los
/// datos crudos (JSON) se convierten acá con [Producto.fromJson], que
/// usa el repositorio.
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    this.emoji = emojiPorDefecto,
    this.descripcion = '',
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      precio: (json['precio'] as num).toDouble(),
      categoria: json['categoria'] as String,
      emoji: json['emoji'] as String? ?? emojiPorDefecto,
      descripcion: json['descripcion'] as String? ?? '',
    );
  }

  static const emojiPorDefecto = '🛒';

  final String id;
  final String nombre;
  final double precio;
  final String categoria;
  final String emoji;
  final String descripcion;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'categoria': categoria,
        'emoji': emoji,
        'descripcion': descripcion,
      };
}
