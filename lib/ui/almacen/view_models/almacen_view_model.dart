import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/sesion_repository.dart';
import '../../../domain/models/producto.dart';
import '../../../domain/models/sesion.dart';
import '../../core/estado_carga.dart';

/// Estado de "Mi almacén": lo que Don Ceferino cambia todos los días.
///
/// Observa dos sujetos (patrón Observer):
/// - el [CatalogoRepository]: cualquier cambio del catálogo (también el
///   producto que se cargó con la foto) llega solo a esta lista;
/// - el [SesionRepository], si se lo pasan: cuando entra el dueño, carga
///   el catálogo fresco del servidor.
class AlmacenViewModel extends ChangeNotifier {
  AlmacenViewModel({
    required CatalogoRepository repositorio,
    SesionRepository? sesion,
  }) : _repositorio = repositorio {
    _suscripciones = [
      repositorio.cambios.listen(_alCambiarCatalogo),
      if (sesion != null) sesion.cambios.listen(_alCambiarSesion),
    ];
  }

  final CatalogoRepository _repositorio;
  late final List<StreamSubscription<Object?>> _suscripciones;

  EstadoCarga _estado = EstadoCarga.cargando;
  List<Producto> _productos = const [];
  bool _fallo = false;
  bool _descartado = false;

  EstadoCarga get estado => _estado;
  List<Producto> get productos => _productos;

  /// El último cambio no se pudo guardar.
  bool get fallo => _fallo;

  Future<void> cargar({bool forzar = false}) async {
    _estado = EstadoCarga.cargando;
    _avisar();
    try {
      _productos = await _repositorio.obtenerProductos(forzar: forzar);
      _estado = EstadoCarga.exito;
    } on Exception {
      _estado = EstadoCarga.error;
    }
    _avisar();
  }

  /// Recibe lo que escribió el dueño ("3.200", "3200", "$3200").
  /// Devuelve false si el texto no es un precio válido.
  Future<bool> cambiarPrecio(Producto producto, String texto) async {
    final soloDigitos = texto.replaceAll(RegExp('[^0-9]'), '');
    final precio = double.tryParse(soloDigitos) ?? 0;
    if (precio <= 0) return false;
    await _guardar(() => _repositorio.cambiarPrecio(producto.id, precio));
    return true;
  }

  Future<void> cambiarDisponible(Producto producto, bool disponible) =>
      _guardar(() => _repositorio.cambiarDisponible(producto.id, disponible));

  Future<void> eliminar(Producto producto) =>
      _guardar(() => _repositorio.eliminar(producto.id));

  // La lista nueva NO se arma acá: llega por _alCambiarCatalogo, igual
  // que le llega a "Comprar".
  Future<void> _guardar(Future<void> Function() cambio) async {
    _fallo = false;
    try {
      await cambio();
    } on Exception {
      _fallo = true;
    }
    _avisar();
  }

  void _alCambiarCatalogo(List<Producto> productos) {
    _productos = productos;
    _estado = EstadoCarga.exito;
    _avisar();
  }

  void _alCambiarSesion(Sesion? sesion) {
    if (sesion?.rol == Rol.dueno) unawaited(cargar(forzar: true));
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    super.dispose();
  }
}
