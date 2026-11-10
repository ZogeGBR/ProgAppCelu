import 'package:sqflite/sqflite.dart';

/// Historial de pedidos en el celular, con SQLite (sqflite).
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
  /// [fabrica] se inyecta (como las capacidades y políticas): en el
  /// celular es la de sqflite; en las pruebas, `databaseFactoryFfi` con una
  /// base en memoria. El soporte de SQLite cambia según la plataforma.
  HistorialDao({
    DatabaseFactory? fabrica,
    String? ruta,
  })  : _fabrica = fabrica ?? databaseFactorySqflitePlugin,
        _ruta = ruta;

  static const tabla = 'pedidos';
  static const version = 2;
  static const _nombreArchivo = 'freshmarket.db';

  final DatabaseFactory _fabrica;
  final String? _ruta;
  Future<Database>? _base;

  // Se abre una sola vez, la primera vez que se usa.
  Future<Database> get _abierta => _base ??= _abrir();

  Future<Database> _abrir() async {
    final ruta =
        _ruta ?? '${await _fabrica.getDatabasesPath()}/$_nombreArchivo';
    return _fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: version,
        // onCreate corre UNA sola vez: cuando el archivo no existía.
        onCreate: (base, _) => crearTablas(base),
        // onUpgrade: celulares que ya tenían la versión 1 instalada. Sin
        // esto, "no such column: direccion" (onCreate no se repite).
        onUpgrade: (base, anterior, _) => migrar(base, anterior),
      ),
    );
  }

  static Future<void> crearTablas(Database base) async {
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

  static Future<void> migrar(Database base, int versionAnterior) async {
    // Versión 1 -> 2: se agregó la dirección de entrega.
    if (versionAnterior < 2) {
      await base.execute(
        "ALTER TABLE $tabla ADD COLUMN direccion TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  @override
  Future<void> guardar(Map<String, Object?> fila) async {
    final base = await _abierta;
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
    final base = await _abierta;
    return base.query(tabla, orderBy: 'fecha DESC', limit: limite);
  }

  @override
  Future<int> borrarAnterioresA(DateTime fecha) async {
    final base = await _abierta;
    // Siempre con "?": nunca se pega texto dentro del SQL (inyección SQL).
    // Y nunca un DELETE sin WHERE: borraría toda la tabla.
    return base.delete(
      tabla,
      where: 'fecha < ?',
      whereArgs: [fecha.toIso8601String()],
    );
  }

  Future<void> cerrar() async {
    final base = _base;
    _base = null;
    if (base != null) await (await base).close();
  }
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
      ..sort((a, b) => (b['fecha']! as String).compareTo(a['fecha']! as String));
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
