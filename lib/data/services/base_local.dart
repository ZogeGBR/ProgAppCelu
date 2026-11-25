import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'carrito_local_service.dart';
import 'historial_dao.dart';

/// La base SQLite de la app en el celular: UN archivo con varias tablas.
///
/// Cada tabla tiene su DAO, que concentra su SQL ([HistorialDao] para
/// `pedidos`, [CarritoDao] para `carrito`). Esta clase solo abre el archivo,
/// crea las tablas la primera vez y migra las bases viejas.
///
/// La [fabrica] se inyecta (como las capacidades y políticas): en el
/// celular es la de sqflite; en las pruebas, `databaseFactoryFfi` con una
/// base en memoria, sin emulador.
class BaseLocal {
  BaseLocal({DatabaseFactory? fabrica, String? ruta})
      : _fabrica = fabrica ?? databaseFactorySqflitePlugin,
        _ruta = ruta;

  /// Versión del esquema: sube cada vez que cambia la forma de una tabla.
  /// 1: pedidos. 2: pedidos con dirección. 3: tabla carrito.
  static const version = 3;
  static const nombreArchivo = 'freshmarket.db';

  final DatabaseFactory _fabrica;
  final String? _ruta;
  Future<Database>? _base;

  /// Se abre una sola vez, la primera vez que alguien la usa.
  Future<Database> get abierta => _base ??= _abrir();

  Future<Database> _abrir() async {
    // join arma la ruta con el separador correcto de cada sistema (/ o \).
    final ruta =
        _ruta ?? p.join(await _fabrica.getDatabasesPath(), nombreArchivo);
    return _fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: version,
        // onCreate corre UNA sola vez: cuando el archivo no existía.
        onCreate: (base, _) => crearTablas(base),
        // onUpgrade: celulares que ya tenían una versión anterior. onCreate
        // no se repite, así que lo nuevo se agrega acá.
        onUpgrade: (base, anterior, _) => migrar(base, anterior),
      ),
    );
  }

  static Future<void> crearTablas(Database base) async {
    await HistorialDao.crearTabla(base);
    await CarritoDao.crearTabla(base);
  }

  static Future<void> migrar(Database base, int versionAnterior) async {
    // 1 -> 2: se agregó la dirección de entrega a los pedidos.
    if (versionAnterior < 2) {
      await base.execute(
        "ALTER TABLE ${HistorialDao.tabla} ADD COLUMN direccion TEXT NOT NULL DEFAULT ''",
      );
    }
    // 2 -> 3: el carrito pasó de preferencias (JSON) a su propia tabla.
    if (versionAnterior < 3) {
      await CarritoDao.crearTabla(base);
    }
  }

  Future<void> cerrar() async {
    final base = _base;
    _base = null;
    if (base != null) await (await base).close();
  }
}
