/// Formatea un precio al estilo argentino: 3800 -> "$3.800".
///
/// Lo hacemos a mano (sin el paquete intl) para no sumar
/// dependencias externas en esta etapa de la materia.
String formatearPrecio(double precio) {
  final digitos = precio.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    // Cada 3 dígitos contando desde la derecha va un punto.
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return '\$$buffer';
}
