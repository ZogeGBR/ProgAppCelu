/// Formatea un precio al estilo argentino: 3800 -> "$3.800".
///
/// Vive en la capa de UI: los ViewModels trabajan con números y el
/// texto para mostrar se arma acá, una sola vez para todas las pantallas.
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
