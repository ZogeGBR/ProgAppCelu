import 'package:flutter/foundation.dart';

import '../../../domain/models/item_carrito.dart';
import '../../../domain/models/metodo_pago.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/producto.dart';

/// Estado del carrito, compartido por el catálogo, el carrito y el pago.
///
/// Fórmula del apunte: dato privado -> getter público -> comando que
/// cambia el dato y termina con notifyListeners().
class CarritoViewModel extends ChangeNotifier {
  CarritoViewModel({DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  static const primerNumeroDePedido = 1001;

  final DateTime Function() _reloj;
  final List<ItemCarrito> _items = [];
  int _proximoNumero = primerNumeroDePedido;

  List<ItemCarrito> get items => List.unmodifiable(_items);

  bool get estaVacio => _items.isEmpty;

  int get cantidadTotal =>
      _items.fold(0, (total, item) => total + item.cantidad);

  double get total => _items.fold(0, (total, item) => total + item.subtotal);

  int cantidadDe(Producto producto) {
    final indice = _indiceDe(producto);
    return indice < 0 ? 0 : _items[indice].cantidad;
  }

  /// Agrega un producto. Si ya estaba, suma uno a la cantidad.
  void agregarProducto(Producto producto) {
    final indice = _indiceDe(producto);
    if (indice < 0) {
      _items.add(ItemCarrito(producto: producto));
    } else {
      final item = _items[indice];
      _items[indice] = item.copiarCon(cantidad: item.cantidad + 1);
    }
    notifyListeners();
  }

  /// Resta uno a la cantidad; si llega a 0, saca el producto.
  void quitarProducto(Producto producto) {
    final indice = _indiceDe(producto);
    if (indice < 0) return;

    final item = _items[indice];
    if (item.cantidad == 1) {
      _items.removeAt(indice);
    } else {
      _items[indice] = item.copiarCon(cantidad: item.cantidad - 1);
    }
    notifyListeners();
  }

  /// Saca el producto entero, sin importar la cantidad.
  void eliminarProducto(Producto producto) {
    final indice = _indiceDe(producto);
    if (indice < 0) return;
    _items.removeAt(indice);
    notifyListeners();
  }

  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }

  /// Arma un pedido con una copia de los ítems, SIN vaciar el carrito:
  /// se vacía recién cuando Mercado Pago confirma el pago. Así, si el
  /// pago falla, la persona no pierde lo que había elegido.
  Pedido armarPedido(MetodoPago metodoPago) {
    final fecha = _reloj();
    final numero = _proximoNumero++;
    return Pedido(
      id: '${fecha.millisecondsSinceEpoch}-$numero',
      numero: numero,
      items: List.unmodifiable(_items),
      metodoPago: metodoPago,
      fecha: fecha,
    );
  }

  int _indiceDe(Producto producto) =>
      _items.indexWhere((item) => item.producto.id == producto.id);
}
