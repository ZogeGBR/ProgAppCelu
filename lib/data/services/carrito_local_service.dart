import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'base_local.dart';
import 'preferencias.dart';

/// El carrito en el celular: una fila por producto.
///
/// Antes se guardaba como un JSON en shared_preferences. La teoría lo
/// señala justo con este ejemplo: una lista de objetos en preferencias
/// obliga a leer, decodificar y reescribir todo en cada cambio, no se puede
/// consultar, y si el JSON cambia de forma los datos viejos dejan de
/// leerse. En una tabla, cada producto es una fila con columnas tipadas.
abstract interface class CarritoLocalService {
  /// Las filas en el orden en que se agregaron.
  Future<List<Map<String, Object?>>> leer();

  /// Reemplaza el carrito guardado por estas filas.
  Future<void> guardar(List<Map<String, Object?>> filas);
}

class CarritoDao implements CarritoLocalService {
  CarritoDao({BaseLocal? base, DatabaseFactory? fabrica, String? ruta})
      : _base = base ?? BaseLocal(fabrica: fabrica, ruta: ruta);

  static const tabla = 'carrito';

  final BaseLocal _base;

  static Future<void> crearTabla(Database base) async {
    // SQLite no tiene bool: "disponible" va como INTEGER (1 = sí, 0 = no).
    await base.execute('''
      CREATE TABLE $tabla (
        producto_id TEXT    PRIMARY KEY,
        nombre      TEXT    NOT NULL,
        precio      REAL    NOT NULL,
        categoria   TEXT    NOT NULL,
        emoji       TEXT    NOT NULL,
        descripcion TEXT    NOT NULL DEFAULT '',
        disponible  INTEGER NOT NULL DEFAULT 1,
        cantidad    INTEGER NOT NULL CHECK (cantidad > 0),
        orden       INTEGER NOT NULL
      )
    ''');
  }

  @override
  Future<List<Map<String, Object?>>> leer() async {
    final base = await _base.abierta;
    return base.query(tabla, orderBy: 'orden');
  }

  @override
  Future<void> guardar(List<Map<String, Object?>> filas) async {
    final base = await _base.abierta;
    // Una transacción: o se guarda el carrito entero o nada. Si la app se
    // cierra a mitad de camino, no queda un carrito a medias.
    await base.transaction((transaccion) async {
      // Acá sí se borra todo a propósito: el carrito se reemplaza entero.
      await transaccion.delete(tabla);
      for (final fila in filas) {
        await transaccion.insert(tabla, fila);
      }
    });
  }

  Future<void> cerrar() => _base.cerrar();
}

/// En memoria: para las pruebas (no toca el disco).
class CarritoLocalServiceMemoria implements CarritoLocalService {
  CarritoLocalServiceMemoria([List<Map<String, Object?>>? guardado])
      : _guardado = guardado ?? const [];

  List<Map<String, Object?>> _guardado;

  List<Map<String, Object?>> get guardado => _guardado;

  @override
  Future<List<Map<String, Object?>>> leer() async => _guardado;

  @override
  Future<void> guardar(List<Map<String, Object?>> filas) async {
    _guardado = [for (final fila in filas) Map.of(fila)];
  }
}

/// En la Web no hay SQLite (es una capacidad de la plataforma): ahí el
/// carrito sigue en shared_preferences, como JSON. La política
/// `puedeGuardarHistorial` decide cuál se usa, no un `if` suelto.
class CarritoLocalServicePreferencias implements CarritoLocalService {
  const CarritoLocalServicePreferencias(this._preferencias);

  final Preferencias _preferencias;

  static const _clave = Preferencias.claveCarrito;

  @override
  Future<List<Map<String, Object?>>> leer() async {
    final guardado = await _preferencias.leer(_clave);
    if (guardado == null || guardado.isEmpty) return const [];
    final lista = jsonDecode(guardado) as List<dynamic>;
    return [for (final fila in lista) Map<String, Object?>.from(fila as Map)];
  }

  @override
  Future<void> guardar(List<Map<String, Object?>> filas) =>
      _preferencias.guardar(_clave, jsonEncode(filas));
}
