import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/carrito_repository.dart';
import '../../../data/repositories/pago_repository.dart';
import '../../../data/repositories/recordatorios_repository.dart';
import '../../../domain/models/item_carrito.dart';
import '../../../domain/models/metodo_pago.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/producto.dart';

/// Estado del carrito, compartido por el catálogo, el carrito y el pago.
///
/// Fórmula del apunte: dato privado -> getter público -> comando que
/// cambia el dato y termina con notifyListeners() (patrón Observer).
///
/// Con [repositorio], el carrito se guarda en el celular: si la app se
/// cierra, al volver a abrirla sigue ahí.
///
/// Con [pagos], observa los pedidos confirmados (patrón Observer) y se
/// vacía solo cuando se aprueba el pago. Si el pago falla, no se toca:
/// la persona no pierde lo que había elegido.
///
/// Con [recordatorios], si la persona sale de la app con el carrito lleno,
/// el celular le recuerda el pedido más tarde (segundo plano).
class CarritoViewModel extends ChangeNotifier {
  CarritoViewModel({
    DateTime Function()? reloj,
    CarritoRepository? repositorio,
    PagoRepository? pagos,
    RecordatoriosRepository? recordatorios,
  })  : _reloj = reloj ?? DateTime.now,
        _repositorio = repositorio,
        _recordatorios = recordatorios {
    _suscripcion = pagos?.pedidosConfirmados.listen((_) => vaciarCarrito());
  }

  static const primerNumeroDePedido = 1001;

  final DateTime Function() _reloj;
  final CarritoRepository? _repositorio;
  final RecordatoriosRepository? _recordatorios;
  late final StreamSubscription<Pedido>? _suscripcion;
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

  /// Recupera el carrito guardado. Si la persona ya agregó algo en esta
  /// sesión, no lo pisa. Un error al leer no frena la app.
  Future<void> restaurar() async {
    final repositorio = _repositorio;
    if (repositorio == null) return;
    try {
      final guardados = await repositorio.cargar();
      if (guardados.isEmpty || _items.isNotEmpty) return;
      _items.addAll(guardados);
      notifyListeners();
    } on Exception {
      // Sin carrito guardado: se empieza de cero.
    }
  }

  /// Guarda el carrito en el celular. Se llama cuando la app pasa a
  /// segundo plano (ver main.dart).
  Future<void> guardar() async {
    try {
      await _repositorio?.guardar(items);
    } on Exception {
      // Si no se pudo guardar, la próxima vez se intenta de nuevo.
    }
  }

  /// La app pasó a segundo plano (evento del sistema, ver main.dart):
  /// primero se guarda y, si quedó algo sin comprar, se programa el
  /// recordatorio.
  Future<void> alOcultarseLaApp() async {
    await guardar();
    final recordatorios = _recordatorios;
    if (recordatorios == null || estaVacio) return;
    try {
      await recordatorios.recordarCarrito(cantidadTotal);
    } on Exception {
      // Sin recordatorio no se pierde nada: el carrito ya quedó guardado.
    }
  }

  /// La persona volvió: el recordatorio ya no hace falta.
  Future<void> alVolverALaApp() async {
    try {
      await _recordatorios?.olvidarCarrito();
    } on Exception {
      // Si no se pudo cancelar, llega un aviso de más: no es grave.
    }
  }

  /// "Volver a pedir": suma estos ítems a lo que ya hay en el carrito.
  void agregarItems(Iterable<ItemCarrito> nuevos) {
    for (final nuevo in nuevos) {
      final indice = _indiceDe(nuevo.producto);
      if (indice < 0) {
        _items.add(nuevo);
      } else {
        final item = _items[indice];
        _items[indice] =
            item.copiarCon(cantidad: item.cantidad + nuevo.cantidad);
      }
    }
    notifyListeners();
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

  @override
  void dispose() {
    unawaited(_suscripcion?.cancel());
    super.dispose();
  }
}
