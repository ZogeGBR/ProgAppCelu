/// Topes de pedidos del almacén (los hace cumplir el servidor).
///
/// Un almacén de barrio recibe hasta unos 100 pedidos por día; el sistema
/// se dimensiona para eso (ver backend/src/cupo.js).
enum LimiteDePedidos {
  /// Ya se aprobaron los pedidos del día: hay que esperar a mañana.
  porDia,

  /// Muchos pedidos en el mismo minuto: alcanza con probar enseguida.
  porMinuto;

  static const maximoPorDia = 100;
  static const maximoPorMinuto = 100;
}

/// El almacén no puede tomar el pedido ahora. No es una falla: es un tope
/// acordado, y la pantalla lo explica con palabras simples.
class SinLugarParaPedidos implements Exception {
  const SinLugarParaPedidos(this.limite);

  final LimiteDePedidos limite;

  @override
  String toString() => 'SinLugarParaPedidos(${limite.name})';
}
