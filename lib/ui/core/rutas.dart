/// Nombres de las pantallas que se abren encima de la principal.
///
/// Se navega con `Navigator.pushNamed(context, Rutas.pago)` y las arma un
/// solo lugar: `onGenerateRoute` en main.dart. Así ninguna pantalla
/// necesita saber cómo se construye otra (ni qué ViewModel lleva).
///
/// Las secciones de la barra de abajo (Comprar, Mi carrito, Mi pedido...)
/// no son rutas: viven en un IndexedStack para no perder lo que la persona
/// estaba haciendo al cambiar de pestaña.
abstract final class Rutas {
  static const ingresar = '/ingresar';
  static const pago = '/pago';
  static const cargarConFoto = '/cargar-con-foto';
}
