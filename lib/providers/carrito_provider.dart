import 'package:flutter/foundation.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';

/// Maneja el estado del carrito de compras de FreshMarket.
///
/// Extiende ChangeNotifier porque este dato (el carrito) lo necesitan
/// varias pantallas a la vez (Home, Carrito, Método de pago,
/// Seguimiento) — no alcanza con el setState() de un solo State,
/// como explica el apunte de la materia.
///
/// Patrón usado (fórmula del apunte): dato privado -> getter público
/// -> método que cambia el dato y termina llamando notifyListeners().
class CarritoProvider extends ChangeNotifier {
  final List<ItemCarrito> _items = [];

  List<ItemCarrito> get items => List.unmodifiable(_items);

  int get cantidadTotal =>
      _items.fold(0, (total, item) => total + item.cantidad);

  double get total => _items.fold(0, (total, item) => total + item.subtotal);

  /// Agrega un producto al carrito. Si ya estaba, suma uno a la cantidad.
  void agregarProducto(Producto producto) {
    final index =
        _items.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      _items[index].cantidad++;
    } else {
      _items.add(ItemCarrito(producto: producto));
    }
    notifyListeners();
  }

  /// Resta uno a la cantidad de un producto; si llega a 0, lo saca
  /// del carrito.
  void quitarProducto(Producto producto) {
    final index =
        _items.indexWhere((item) => item.producto.id == producto.id);
    if (index < 0) return;
    if (_items[index].cantidad > 1) {
      _items[index].cantidad--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  int cantidadDe(Producto producto) {
    final index =
        _items.indexWhere((item) => item.producto.id == producto.id);
    return index >= 0 ? _items[index].cantidad : 0;
  }

  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }
}
