import 'package:shared_preferences/shared_preferences.dart';

/// Todo lo que la app guarda como "clave y valor" en el celular.
///
/// Patrón Preferencias de la teoría: las claves son constantes en UN solo
/// lugar (un error de tipeo en una clave es un dato que "desaparece") y se
/// usa `SharedPreferencesAsync`, la API recomendada hoy: no tiene caché
/// propia, así que no queda vieja si otro isolate escribió (por ejemplo, el
/// manejador de push en segundo plano).
///
/// Solo guarda texto: pasar objetos a JSON es trabajo de los repositorios.
class Preferencias {
  const Preferencias();

  static const claveCarrito = 'carrito_v1';
  static const clavePedidoEnCurso = 'pedido_en_curso_v1';
  static const claveUltimoAvisoEnSegundoPlano = 'ultimo_aviso_segundo_plano';

  Future<String?> leer(String clave) => SharedPreferencesAsync().getString(clave);

  Future<void> guardar(String clave, String valor) =>
      SharedPreferencesAsync().setString(clave, valor);

  Future<void> borrar(String clave) => SharedPreferencesAsync().remove(clave);
}
