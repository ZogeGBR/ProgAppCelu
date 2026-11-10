import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/historial_repository.dart';
import '../../../data/repositories/pago_repository.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/pedido_anterior.dart';

/// "Tus pedidos anteriores", con el botón "Volver a pedir".
///
/// Observa los pedidos confirmados (Observer) y los guarda en el
/// historial del celular, sin que la pantalla de pago sepa que existe.
class HistorialViewModel extends ChangeNotifier {
  HistorialViewModel({
    required HistorialRepository repositorio,
    PagoRepository? pagos,
  }) : _repositorio = repositorio {
    _suscripcion = pagos?.pedidosConfirmados.listen(
      (pedido) => unawaited(_guardar(pedido)),
    );
  }

  final HistorialRepository _repositorio;
  late final StreamSubscription<Pedido>? _suscripcion;

  List<PedidoAnterior> _pedidos = const [];
  bool _cargando = false;
  bool _descartado = false;

  List<PedidoAnterior> get pedidos => _pedidos;
  bool get cargando => _cargando;
  bool get hayPedidos => _pedidos.isNotEmpty;

  Future<void> cargar() async {
    _cargando = true;
    _avisar();
    try {
      // Dos tareas independientes: van en paralelo con Future.wait y se
      // espera a la más lenta (no a la suma de las dos).
      final resultados = await Future.wait([
        _repositorio.ultimos(),
        _repositorio.limpiarViejos(),
      ]);
      _pedidos = resultados.first as List<PedidoAnterior>;
    } on Exception {
      // Sin historial no pasa nada: la sección simplemente no aparece.
      _pedidos = const [];
    } finally {
      // finally corre siempre, salga bien o mal: nunca queda "cargando".
      _cargando = false;
      _avisar();
    }
  }

  Future<void> _guardar(Pedido pedido) async {
    try {
      await _repositorio.guardar(pedido);
      await cargar();
    } on Exception {
      // Guardar el historial nunca frena una compra.
    }
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    unawaited(_suscripcion?.cancel());
    super.dispose();
  }
}
