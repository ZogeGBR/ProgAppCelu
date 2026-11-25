import 'package:shared_preferences/shared_preferences.dart';

/// Todo lo que la app guarda como "clave y valor" en el celular.
///
/// Patrón Preferencias de la teoría:
/// - Las claves son constantes en UN solo lugar: un error de tipeo en una
///   clave suelta no avisa nada, lee null para siempre.
/// - Se usa `SharedPreferencesAsync`, la API que recomienda la materia: no
///   tiene caché propia, así que no queda vieja si otro isolate escribió
///   (por ejemplo, el manejador de push en segundo plano).
/// - La instancia se recibe por el constructor (inyección): la app usa el
///   almacenamiento del celular y las pruebas, uno en memoria
///   (`InMemorySharedPreferencesAsync`).
///
/// Acá van solo valores sueltos y chicos. Las listas de objetos (el
/// carrito, el historial) van en SQLite: ver base_local.dart.
class Preferencias {
  Preferencias([SharedPreferencesAsync? almacen]) : _inyectado = almacen;

  final SharedPreferencesAsync? _inyectado;

  // Sin uno inyectado, se crea al usarse y no al construir: crear un
  // SharedPreferencesAsync sin la plataforma lista (por ejemplo, en las
  // pruebas de pantallas, donde no hay celular) lanza un error. No tiene
  // caché, así que crearlo de nuevo no cuesta nada.
  SharedPreferencesAsync get _almacen => _inyectado ?? SharedPreferencesAsync();

  /// Solo en la Web, donde no hay SQLite (ver CarritoLocalServicePreferencias).
  static const claveCarrito = 'carrito_v1';

  /// El pedido que se está siguiendo: UN objeto chico, por eso alcanza con
  /// una preferencia (como JSON).
  static const clavePedidoEnCurso = 'pedido_en_curso_v1';
  static const claveUltimoAvisoEnSegundoPlano = 'ultimo_aviso_segundo_plano';

  /// Todas las claves de la app, para borrar solo las nuestras.
  static const todasLasClaves = {
    claveCarrito,
    clavePedidoEnCurso,
    claveUltimoAvisoEnSegundoPlano,
  };

  Future<String?> leer(String clave) => _almacen.getString(clave);

  Future<void> guardar(String clave, String valor) =>
      _almacen.setString(clave, valor);

  Future<void> borrar(String clave) => _almacen.remove(clave);

  /// Borra solo las claves de la app, no las que hayan guardado otros
  /// paquetes (`clear()` sin lista las borraría todas).
  Future<void> olvidarTodo() => _almacen.clear(allowList: todasLasClaves);
}
