import 'dart:math' as math;

import 'posicion.dart';

/// Un camino por las calles: la lista de puntos que sigue la bicicleta.
///
/// Sabe cuánto mide y dónde está la bici después de andar cierta cantidad
/// de metros. Así la bici avanza POR el camino (dobla en las esquinas) y no
/// en línea recta entre dos puntos lejanos.
class Recorrido {
  Recorrido(List<Posicion> puntos)
      : puntos = List.unmodifiable(puntos),
        _acumulados = _medir(puntos);

  /// Un camino en línea recta: lo que se usa si no se pudo calcular la ruta.
  Recorrido.recto(Posicion desde, Posicion hasta) : this([desde, hasta]);

  final List<Posicion> puntos;

  /// Metros desde el inicio hasta cada punto (el primero es 0).
  final List<double> _acumulados;

  static const _radioTierra = 6371000.0; // metros

  double get largoMetros => _acumulados.isEmpty ? 0 : _acumulados.last;

  bool get esValido => puntos.length >= 2;

  /// Dónde está la bici después de andar [metros] desde el inicio.
  Posicion puntoA(double metros) {
    if (puntos.isEmpty) {
      throw StateError('Un recorrido sin puntos no tiene posiciones.');
    }
    if (puntos.length == 1 || metros <= 0) return puntos.first;
    if (metros >= largoMetros) return puntos.last;

    // El tramo donde cae esa distancia.
    var tramo = 1;
    while (tramo < _acumulados.length - 1 && _acumulados[tramo] < metros) {
      tramo++;
    }
    final inicio = _acumulados[tramo - 1];
    final largo = _acumulados[tramo] - inicio;
    final avance = largo == 0 ? 0.0 : (metros - inicio) / largo;
    return _entre(puntos[tramo - 1], puntos[tramo], avance);
  }

  /// Dónde está la bici al haber hecho esa fracción del camino (0 a 1).
  Posicion puntoEnFraccion(double fraccion) =>
      puntoA(fraccion.clamp(0.0, 1.0) * largoMetros);

  /// Cuántos metros del camino hay hasta el punto del camino más cercano a
  /// [posicion]. Sirve para animar la bici desde donde estaba hasta la
  /// posición nueva siguiendo las calles.
  double metrosHasta(Posicion posicion) {
    if (puntos.length < 2) return 0;
    var mejorDistancia = double.infinity;
    var mejorMetros = 0.0;
    for (var i = 1; i < puntos.length; i++) {
      final a = puntos[i - 1];
      final b = puntos[i];
      final t = _proyeccion(a, b, posicion);
      final cercano = _entre(a, b, t);
      final distancia = distanciaMetros(cercano, posicion);
      if (distancia < mejorDistancia) {
        mejorDistancia = distancia;
        mejorMetros =
            _acumulados[i - 1] + t * (_acumulados[i] - _acumulados[i - 1]);
      }
    }
    return mejorMetros;
  }

  /// Distancia en metros entre dos puntos (fórmula de haversine).
  static double distanciaMetros(Posicion a, Posicion b) {
    final lat1 = _radianes(a.latitud);
    final lat2 = _radianes(b.latitud);
    final dLat = lat2 - lat1;
    final dLng = _radianes(b.longitud - a.longitud);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _radioTierra * math.asin(math.min(1, math.sqrt(h)));
  }

  static List<double> _medir(List<Posicion> puntos) {
    final acumulados = <double>[];
    var total = 0.0;
    for (var i = 0; i < puntos.length; i++) {
      if (i > 0) total += distanciaMetros(puntos[i - 1], puntos[i]);
      acumulados.add(total);
    }
    return acumulados;
  }

  /// Fracción (0 a 1) del tramo a→b más cercana a p. En distancias de una
  /// ciudad alcanza con tratar latitud y longitud como un plano, corrigiendo
  /// la longitud por el coseno de la latitud.
  static double _proyeccion(Posicion a, Posicion b, Posicion p) {
    final escala = math.cos(_radianes(a.latitud));
    final abX = (b.longitud - a.longitud) * escala;
    final abY = b.latitud - a.latitud;
    final apX = (p.longitud - a.longitud) * escala;
    final apY = p.latitud - a.latitud;
    final largo2 = abX * abX + abY * abY;
    if (largo2 == 0) return 0;
    return ((apX * abX + apY * abY) / largo2).clamp(0.0, 1.0);
  }

  static Posicion _entre(Posicion a, Posicion b, double t) => Posicion(
        latitud: a.latitud + (b.latitud - a.latitud) * t,
        longitud: a.longitud + (b.longitud - a.longitud) * t,
      );

  static double _radianes(double grados) => grados * math.pi / 180;
}
