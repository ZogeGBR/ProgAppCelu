/// La etiqueta de un producto nuevo que arma la IA a partir de una foto.
///
/// Es solo una sugerencia: el dueño la revisa, puede corregir cualquier
/// dato (sobre todo el precio) y recién al confirmar se guarda.
class FichaProducto {
  const FichaProducto({
    required this.nombre,
    required this.categoria,
    required this.precio,
    this.descripcion = '',
    this.emoji = '🛒',
  });

  factory FichaProducto.fromJson(Map<String, dynamic> json) => FichaProducto(
        nombre: json['nombre'] as String? ?? '',
        categoria: json['categoria'] as String? ?? 'Almacén',
        precio: (json['precioSugerido'] as num?)?.toDouble() ?? 0,
        descripcion: json['descripcion'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🛒',
      );

  final String nombre;
  final String categoria;
  final double precio;
  final String descripcion;
  final String emoji;

  bool get estaCompleta => nombre.trim().isNotEmpty && precio > 0;

  FichaProducto copiarCon({
    String? nombre,
    String? categoria,
    double? precio,
    String? descripcion,
  }) =>
      FichaProducto(
        nombre: nombre ?? this.nombre,
        categoria: categoria ?? this.categoria,
        precio: precio ?? this.precio,
        descripcion: descripcion ?? this.descripcion,
        emoji: emoji,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre.trim(),
        'categoria': categoria,
        'precio': precio,
        'descripcion': descripcion.trim(),
        'emoji': emoji,
      };
}
