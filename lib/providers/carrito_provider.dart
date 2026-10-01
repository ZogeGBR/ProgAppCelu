import 'package:flutter/foundation.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../models/metodo_pago.dart';
import '../models/pedido.dart';

/// Maneja el estado del carrito de compras de FreshMarket.
///
/// Extiende ChangeNotifier porque este dato (el carrito) lo necesitan
/// varias pantallas a la vez (Home, Carrito, Método de pago) — no
/// alcanza con el setState() de un solo State, como explica el apunte
/// de la materia.
///
/// Patrón usado (fórmula del apunte): dato privado -> getter público
/// -> método que cambia el dato y termina llamando notifyListeners().
class CarritoProvider extends ChangeNotifier {
  final List<ItemCarrito> _items = [];
  int _proximoNumeroPedido = 1001;

  List<ItemCarrito> get items => List.unmodifiable(_items);

  bool get estaVacio => _items.isEmpty;

  int get cantidadTotal =>
      _items.fold(0, (total, item) => total + item.cantidad);

  double get total => _items.fold(0, (total, item) => total + item.subtotal);

  /// Agrega un producto al carrito. Si ya estaba, suma uno a la cantidad.
  void agregarProducto(Producto producto) {
    final index = _indiceDe(producto);
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
    final index = _indiceDe(producto);
    if (index < 0) return;
    if (_items[index].cantidad > 1) {
      _items[index].cantidad--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  /// Saca el producto del carrito entero, sin importar la cantidad.
  void eliminarProducto(Producto producto) {
    final index = _indiceDe(producto);
    if (index < 0) return;
    _items.removeAt(index);
    notifyListeners();
  }

  int cantidadDe(Producto producto) {
    final index = _indiceDe(producto);
    return index >= 0 ? _items[index].cantidad : 0;
  }

  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }

  /// Confirma el pedido: arma un Pedido con una copia de los ítems
  /// actuales y vacía el carrito.
  ///
  /// Se llama desde el botón de pagar (un evento del usuario), nunca
  /// desde initState() o build(): avisar a los listeners mientras
  /// Flutter está construyendo una pantalla dispara el error
  /// "setState() called during build".
  Pedido confirmarPedido(MetodoPago metodoPago) {
    final pedido = Pedido(
      numero: _proximoNumeroPedido++,
      items: _items
          .map((item) =>
              ItemCarrito(producto: item.producto, cantidad: item.cantidad))
          .toList(),
      total: total,
      metodoPago: metodoPago,
      fecha: DateTime.now(),
    );
    vaciarCarrito();
    return pedido;
  }

  int _indiceDe(Producto producto) =>
      _items.indexWhere((item) => item.producto.id == producto.id);
}
