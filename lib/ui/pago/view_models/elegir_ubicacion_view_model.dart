import 'package:flutter/foundation.dart';

import '../../../data/repositories/ubicacion_entrega_repository.dart';
import '../../../domain/models/posicion.dart';
import '../../../domain/models/ubicacion_entrega.dart';

/// Qué está pasando en el mapa para marcar la casa.
enum EstadoUbicacion {
  sinMarcar,
  buscandoDireccion,
  conDireccion,
  sinCalle,
  error,
}

/// Estado de la pantalla "Tocá dónde vivís".
///
/// Cada toque en el mapa pide la dirección de ese punto. Si la persona
/// toca varias veces rápido, solo vale la ÚLTIMA respuesta: las anteriores
/// se ignoran aunque lleguen tarde.
class ElegirUbicacionViewModel extends ChangeNotifier {
  ElegirUbicacionViewModel({
    required UbicacionEntregaRepository repositorio,
    Posicion? inicial,
    String direccionInicial = '',
  })  : _repositorio = repositorio,
        _punto = inicial,
        _direccion = direccionInicial,
        _estado = inicial == null
            ? EstadoUbicacion.sinMarcar
            : EstadoUbicacion.conDireccion;

  final UbicacionEntregaRepository _repositorio;

  Posicion? _punto;
  String _direccion;
  EstadoUbicacion _estado;
  bool _buscandoGps = false;
  bool _sinGps = false;
  int _consulta = 0;
  bool _descartado = false;

  Posicion? get punto => _punto;
  String get direccion => _direccion;
  EstadoUbicacion get estado => _estado;
  bool get buscandoGps => _buscandoGps;

  /// El GPS está apagado o no dio permiso: se avisa una vez.
  bool get sinGps => _sinGps;

  /// Se puede confirmar con cualquier punto marcado: si no se encontró la
  /// calle, la persona la escribe a mano en la pantalla de pago.
  bool get puedeConfirmar =>
      _punto != null && _estado != EstadoUbicacion.buscandoDireccion;

  UbicacionEntrega? get resultado {
    final punto = _punto;
    if (punto == null || !puedeConfirmar) return null;
    return UbicacionEntrega(posicion: punto, direccion: _direccion);
  }

  /// La persona tocó el mapa.
  Future<void> marcar(Posicion punto) async {
    final consulta = ++_consulta;
    _punto = punto;
    _direccion = '';
    _estado = EstadoUbicacion.buscandoDireccion;
    _avisar();

    try {
      final direccion = await _repositorio.direccionDe(punto);
      if (consulta != _consulta) return; // Ya tocó otro lugar.
      _direccion = direccion;
      _estado = direccion.isEmpty
          ? EstadoUbicacion.sinCalle
          : EstadoUbicacion.conDireccion;
    } on Exception {
      if (consulta != _consulta) return;
      _estado = EstadoUbicacion.error;
    }
    _avisar();
  }

  /// Botón "Usar mi ubicación".
  Future<void> usarMiUbicacion() async {
    if (_buscandoGps) return;
    _buscandoGps = true;
    _sinGps = false;
    _avisar();

    Posicion? aca;
    try {
      aca = await _repositorio.miPosicion();
    } on Exception {
      aca = null;
    }
    _buscandoGps = false;
    _sinGps = aca == null;
    _avisar();
    if (aca != null) await marcar(aca);
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
