import 'package:sqflite/sqflite.dart';

import 'base_local.dart';

/// Historial de pedidos en el celular.
///
/// Patrón DAO (Data Access Object): esta clase concentra TODO el SQL de la
/// tabla `pedidos`. El resto de la app solo llama a [guardar], [ultimos] y
/// [borrarAnterioresA].
///
/// Por qué SQLite y no shared_preferences: una lista de pedidos con
/// fechas, que se ordena y se recorta, es una tabla. "Lista de objetos como
/// JSON en preferences = señal de pasar a base de datos" (teoría).
abstract interface class HistorialService {
  Future<void> guardar(Map<String, Object?> fila);

  /// Los más nuevos primero.
  Future<List<Map<String, Object?>>> ultimos({int limite = 20});

  /// Borra los pedidos de antes de [fecha]. Devuelve cuántos borró.
  Future<int> borrarAnterioresA(DateTime fecha);
}

class HistorialDao implements HistorialService {
  /// Recibe la [base] compartida. [fabrica] y [ruta] son un atajo para las
  /// pruebas: arman una base propia.
  HistorialDao({BaseLocal? base, DatabaseFactory? fabrica, String? ruta})
      : _base = base ?? BaseLocal(fabrica: fabrica, ruta: ruta);

  static const tabla = 'pedidos';

  final BaseLocal _base;

  static Future<void> crearTabla(Database base) async {
    // SQLite no tiene bool ni DATE: la fecha va como TEXT (ISO 8601).
    await base.execute('''
      CREATE TABLE $tabla (
        id          TEXT    PRIMARY KEY,
        numero      INTEGER NOT NULL,
        fecha       TEXT    NOT NULL,
        metodo_pago TEXT    NOT NULL,
        total       REAL    NOT NULL,
        items       TEXT    NOT NULL,
        direccion   TEXT    NOT NULL DEFAULT ''
      )
    ''');
    await base.execute('CREATE INDEX idx_pedidos_fecha ON $tabla (fecha)');
  }

  @override
  Future<void> guardar(Map<String, Object?> fila) async {
    final base = await _base.abierta;
    // El mismo pedido dos veces (por ejemplo, el aviso llegó repetido)
    // reemplaza a la fila anterior en vez de duplicarla.
    await base.insert(
      tabla,
      fila,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, Object?>>> ultimos({int limite = 20}) async {
    final base = await _base.abierta;
    return base.query(tabla, orderBy: 'fecha DESC', limit: limite);
  }

  @override
  Future<int> borrarAnterioresA(DateTime fecha) async {
    final base = await _base.abierta;
    // Siempre con "?": nunca se pega texto dentro del SQL (inyección SQL).
    // Y nunca un DELETE sin WHERE: borraría toda la tabla.
    return base.delete(
      tabla,
      where: 'fecha < ?',
      whereArgs: [fecha.toIso8601String()],
    );
  }

  Future<void> cerrar() => _base.cerrar();
}

/// En memoria: para la Web (donde SQLite no existe) y las pruebas de
/// pantallas.
class HistorialServiceMemoria implements HistorialService {
  final _filas = <String, Map<String, Object?>>{};

  @override
  Future<void> guardar(Map<String, Object?> fila) async {
    _filas[fila['id']! as String] = Map.of(fila);
  }

  @override
  Future<List<Map<String, Object?>>> ultimos({int limite = 20}) async {
    final ordenadas = _filas.values.toList()
      ..sort(
          (a, b) => (b['fecha']! as String).compareTo(a['fecha']! as String));
    return ordenadas.take(limite).toList();
  }

  @override
  Future<int> borrarAnterioresA(DateTime fecha) async {
    final limite = fecha.toIso8601String();
    final viejas = _filas.entries
        .where((fila) => (fila.value['fecha']! as String).compareTo(limite) < 0)
        .map((fila) => fila.key)
        .toList();
    viejas.forEach(_filas.remove);
    return viejas.length;
  }
}
