import 'package:flutter/foundation.dart';

/// Las secciones de la barra de abajo, en orden.
enum Seccion { comprar, carrito, miPedido, cargarProducto }

/// Qué sección de la barra inferior está abierta.
class NavegacionViewModel extends ChangeNotifier {
  Seccion _actual = Seccion.comprar;

  Seccion get actual => _actual;

  void irA(Seccion seccion) {
    if (seccion == _actual) return;
    _actual = seccion;
    notifyListeners();
  }
}
