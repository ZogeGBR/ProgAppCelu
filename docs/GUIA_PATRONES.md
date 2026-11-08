# Guía de patrones para el oral

Para **entender** (no solo nombrar) cada patrón que usa FreshMarket: qué
problema resuelve, dónde está en el código, cómo funciona y qué puede
preguntar la profesora. Los ejemplos son código real del proyecto
(recortado).

> Cómo estudiarla: para cada patrón, abrí el archivo que se indica y
> seguí el recorrido con el dedo. Si podés explicar el "¿qué pasa si...?" de
> cada sección, lo entendiste.

---

## 1. Observer (el más importante)

**Qué es.** Un objeto (el **sujeto**) tiene datos que cambian. Otros
objetos (los **observadores**) se **suscriben** para que les avise. El
sujeto no sabe quiénes son ni qué hacen con el aviso: solo avisa.

Tiene tres partes: **suscribirse**, **avisar** y **darse de baja**. Si
alguien se olvida de darse de baja, el sujeto le sigue avisando a un
objeto que ya no existe (pérdida de memoria o error).

### Nivel 1: la vista observa al ViewModel

| Parte | En Flutter | En FreshMarket |
|---|---|---|
| Sujeto | `ChangeNotifier` | Cada ViewModel (`CarritoViewModel`, ...) |
| Avisar | `notifyListeners()` | Al final de cada comando que cambia algo |
| Suscribirse | `ListenableBuilder(listenable: ...)` o `addListener` | Cada Screen |
| Darse de baja | Lo hace solo `ListenableBuilder`; con `addListener` hay que llamar a `removeListener` | `ElegirUbicacionScreen.dispose()` |

```dart
// lib/ui/carrito/view_models/carrito_view_model.dart
void agregarProducto(Producto producto) {
  ...                 // cambia el dato privado _items
  notifyListeners();  // avisa: "cambié"
}

// lib/ui/carrito/widgets/carrito_screen.dart
ListenableBuilder(
  listenable: carrito,                 // se suscribe
  builder: (context, _) => Text(...),  // se vuelve a dibujar con cada aviso
)
```

La barra de abajo observa **cuatro** sujetos a la vez con
`Listenable.merge([navegacion, carrito, seguimiento, sesion])`
(`inicio_screen.dart`): por eso el numerito del carrito se actualiza solo.

### Nivel 2: el ViewModel observa al repositorio (cambio del 07-11)

Antes, para que al aprobarse un pago se vaciara el carrito y arrancara el
seguimiento, `InicioScreen` le pasaba al pago un callback que llamaba a los
otros dos ViewModels. Funcionaba, pero cada ViewModel nuevo obligaba a
acordarse de llamarlo desde todos lados.

Ahora el **repositorio es el sujeto** y publica en un `Stream`:

```dart
// lib/data/repositories/pago_repository.dart  (sujeto)
final _confirmados = StreamController<Pedido>.broadcast(sync: true);
Stream<Pedido> get pedidosConfirmados => _confirmados.stream;

void _confirmar(Pedido pedido) {
  if (_idsConfirmados.add(pedido.id)) _confirmados.add(pedido);  // avisar
}

// lib/ui/carrito/view_models/carrito_view_model.dart  (observador)
CarritoViewModel({..., PagoRepository? pagos}) {
  _suscripcion = pagos?.pedidosConfirmados.listen((_) => vaciarCarrito());
}
void dispose() {
  _suscripcion?.cancel();   // darse de baja
  super.dispose();
}
```

| Sujeto | Observadores |
|---|---|
| `CatalogoRepository.cambios` | "Comprar" y "Mi almacén": el dueño cambia un precio y se ve al comprar |
| `SesionRepository.cambios` | `ApiClient` (token), barra de abajo, "Mi almacén", reparto, avisos |
| `PagoRepository.pedidosConfirmados` | Carrito (se vacía), "Mi pedido" (lo sigue), avisos (anota el celular) |
| `NotificacionesRepository.tocados` | Barra de abajo (abre la sección del aviso) |
| `NotificacionesRepository.recibidos` | Reparto (recarga la lista con un pedido nuevo) |

**¿Por qué `broadcast`?** Un `Stream` común admite **un** solo oyente; el
broadcast admite muchos (el pedido confirmado le interesa a tres).

**¿Por qué `sync: true`?** Para que los observadores se enteren en el
mismo instante en que cambia el dato. Ejemplo: el `ApiClient` tiene que
tener el token **antes** de que "Mi almacén" haga su primer pedido
autenticado.

### Nivel 3: Observer en el backend

`backend/src/eventos.js` es un `EventEmitter` de Node. Pagos y seguimiento
**anuncian** ("pedido aprobado", "salió el repartidor", "entregado") y
`avisos.js` **escucha** y manda el push. Si mañana hay que mandar también un
mail, se agrega otro oyente sin tocar los pagos.

### Preguntas probables

- **¿Qué diferencia hay entre Observer y un callback?** El callback es
  uno a uno y el que llama sabe a quién llama. En Observer el sujeto no
  conoce a nadie y puede haber cualquier cantidad de observadores.
- **¿Qué pasa si un observador no se da de baja?** El sujeto le sigue
  avisando. Si es un `ChangeNotifier` descartado, `notifyListeners()` tira
  error. Por eso cada ViewModel cancela sus suscripciones en `dispose()`
  (hay una prueba: "una pantalla dada de baja deja de observar").
- **¿El `setState` es Observer?** Es el caso más chico: el `State` se avisa
  a sí mismo. Se usa solo para estado de **la vista** (el ojo de la
  contraseña en `CampoClave`), que no le importa a nadie más.
- **¿Dónde están las pruebas?** `test/observer_test.dart`.

---

## 2. MVVM (la versión de MVC de Flutter)

| Pieza | Qué hace | En FreshMarket |
|---|---|---|
| **Model** | Los datos y cómo se obtienen | `domain/models` + `data/repositories` + `data/services` |
| **View** | Dibuja y avisa los toques | `ui/*/widgets/*_screen.dart` |
| **ViewModel** | Estado de la pantalla + comandos | `ui/*/view_models/*_view_model.dart` |

Diferencia con MVC: en MVC el controlador le **dice** a la vista qué
cambiar. En MVVM la vista **observa** al ViewModel y se redibuja sola. Por
eso el ViewModel no importa `material.dart`, no recibe `BuildContext` y se
puede probar sin pantalla (todas las pruebas de `test/*_view_model_test.dart`).

**Pregunta probable:** *"¿Dónde está el controlador?"* → El ViewModel hace
de controlador: recibe la acción (`agregarProducto`), cambia el estado y
avisa.

---

## 3. Repository

**Qué es.** Una clase que es la **única fuente de verdad** de un tipo de
dato. Esconde de dónde vienen los datos (red, disco, caché).

**En FreshMarket** (`lib/data/repositories/`, 9 repositorios):
- Convierte JSON en modelos (`Producto.fromJson`).
- Guarda caché (`CatalogoRepository._cache`, `UbicacionEntregaRepository._cache`).
- Reintenta (`_conUnReintento`) y espera (`PagoRepository.seguirEstado`).
- **Desde el 07-11, avisa sus cambios** (ver Observer).

**Pregunta probable:** *"¿Por qué no llama el ViewModel directo al
servicio?"* → Porque la caché, el reintento y la conversión quedarían
repetidos en cada ViewModel. Y si cambia el backend, se toca un solo lugar.

---

## 4. Inyección de dependencias

**Qué es.** Una clase **recibe** lo que necesita por el constructor en vez
de crearlo adentro.

```dart
CatalogoRepository({required CatalogoService service})  // lo recibe
```

`lib/config/dependencias.dart` es el **único** lugar que arma todo:
`Dependencias.desdeConfiguracion()` (real) o `Dependencias.simuladas()`
(demo y pruebas).

**¿Para qué?** Para las pruebas: `test/fakes.dart` tiene versiones falsas
de cada servicio (`CatalogoServiceFalso`, `PushFalso`, ...) que responden
al instante y sin internet. Sin inyección de dependencias no se podrían
reemplazar.

---

## 5. Strategy

**Qué es.** Varias formas intercambiables de hacer lo mismo, detrás de una
misma interfaz. Se elige una al armar la app, sin `if` repartidos.

| Interfaz | Estrategias |
|---|---|
| `PushService` | `PushServiceFirebase` / `PushServiceSimulado` |
| `CatalogoService` | `CatalogoServiceHttp` / `CatalogoServiceLocal` |
| `PagoService` | `PagoServiceHttp` / `PagoServiceSimulado` |
| ... (14 interfaces en total) | |
| Backend `push.js` | Firebase o consola |
| Backend `correo.js` | SMTP o consola |
| Backend `geo.js` | Google, Nominatim o simulado |

**Pregunta probable:** *"¿Strategy y la inyección de dependencias no son
lo mismo?"* → Se usan juntas. Strategy es **tener** varias versiones
intercambiables; la inyección de dependencias es **cómo se le pasa** la
elegida a quien la usa.

---

## 6. Factory

**Qué es.** Un método que sabe **construir** un objeto, para que nadie más
tenga que saber cómo.

- `Producto.fromJson`, `Aviso.desdeDatos`, `Sesion.fromJson`: de datos crudos
  a modelo.
- `Dependencias.desdeConfiguracion()` / `.simuladas()`: arman todo el árbol.
- Backend: `crearPush()`, `crearCorreo()`, `crearGeocodificador()` devuelven
  la estrategia que corresponde según la configuración.

---

## 7. Adapter

**Qué es.** Traduce algo de afuera a la forma que espera tu código.

- `PushServiceFirebase._aAviso`: convierte el `RemoteMessage` de Firebase en
  un `Aviso` del dominio. El resto de la app no sabe que existe Firebase.
- Backend `geo.js`: Google y Nominatim responden distinto; los dos se
  convierten en `{ direccion }`.

---

## 8. Singleton (y por qué casi no se usa)

**Qué es.** Una clase con **una sola instancia** para toda la app.

- Backend: una sola conexión a la base (`bd.js`) y un solo emisor de
  eventos (`eventos.js`).
- App: `FirebaseMessaging.instance` y `SharedPreferences.getInstance()`
  (vienen así de los paquetes).

En nuestro código de la app **no** hay ninguna clase con `static instancia`.
Un Singleton clásico es estado global: no se puede reemplazar en una prueba.
`Dependencias` crea **una** instancia de cada repositorio y la pasa por
constructor: la misma garantía, pero se puede probar.

---

## 9. Callbacks (ahora solo de hijo a padre)

**Qué es.** Pasarle a un widget una función para que avise algo.

Se usa **de la vista hacia quien la armó**: `alVerPedido`, `alIrAComprar`,
`onAgregar` en `ProductoCard`, `crearElegirUbicacion`.

Ya **no** se usa entre ViewModels (eso pasó a Observer el 07-11).

**Pregunta probable:** *"¿Por qué el pago sigue recibiendo `armarPedido`
como callback y no observa al carrito?"* → Porque no es un **aviso** de
algo que pasó: es una **pregunta** ("dame el pedido armado") que el pago
hace en un momento puntual. Observer sirve para enterarse de cambios, no
para pedir datos.

---

## 10. Encapsulamiento e inmutabilidad

- Datos privados con `_` y getters públicos: `_items` / `items`.
- Las listas que salen son `List.unmodifiable`: nadie puede hacer
  `carrito.items.add(...)` y saltarse el `notifyListeners()`.
- Modelos con campos `final` y `copiarCon(...)` para "cambiarlos".
- El token del `ApiClient` es privado: solo cambia con `usarToken()`.

---

## 11. Programación asíncrona

| Concepto | Dónde |
|---|---|
| `Future` / `async` / `await` | Toda llamada a red, disco, GPS, cámara, permisos |
| `Stream` | Seguimiento del pedido, GPS del repartidor, estado del pago, avisos push, **y los cambios de los repositorios** |
| `Stream.periodic` | Consultar el seguimiento y el pago cada 3 s |
| `async*` / `yield` | `PushServiceFirebase.tocados`: primero el aviso que abrió la app, después los demás |
| Timeout | `ApiClient` 10 s, IA 30 s, GPS 15 s, Firebase 5 s al arrancar, pago 5 min |
| `Isolate.run` | Pasar la foto a base64 sin trabar la animación |
| `unawaited(...)` | Cuando a propósito no se espera (guardar el carrito al salir) |
| `mounted` después de un `await` | `IngresarScreen`, `_DireccionState` |
| Respuestas viejas | `ElegirUbicacionViewModel.marcar` numera cada consulta y descarta las viejas |

---

## 12. Eventos del sistema, segundo plano y notificaciones

- `AppLifecycleListener` (`main.dart`): al pasar a segundo plano se guarda
  el carrito.
- `PopScope`: no se puede salir con "atrás" mientras se paga.
- **Notificaciones push** (07-11): con la app cerrada, Android muestra el
  aviso solo (el backend manda `notification`). Con la app abierta la app
  lo recibe y lo muestra con una notificación local. Al tocarla se abre la
  sección. Detalle completo en [`NOTIFICACIONES.md`](NOTIFICACIONES.md).
- **Permisos**: ubicación, cámara y notificaciones se piden cuando hacen
  falta. Si se niegan, la app sigue y explica para qué sirven.

**Pregunta probable:** *"¿Por qué hace falta una notificación local si ya
tienen Firebase?"* → Porque con la app **abierta** Android no muestra el
push en la barra: se lo entrega a la app. Para que se vea igual, la app lo
muestra.

---

## 13. Recorrido completo para contar en el oral

"El cliente paga en efectivo":

1. `PagoScreen` → `PagoViewModel.pagar()` (comando).
2. `PagoRepository.iniciarPago()` → `PagoServiceHttp` → `POST /pagos/preferencia`.
3. El backend guarda el pedido y **anuncia** `pedidoAprobado` → `avisos.js`
   manda "Nuevo pedido" al celular del dueño (Firebase).
4. En la app, `PagoRepository` **publica** el pedido confirmado:
   - `CarritoViewModel` se vacía → `notifyListeners()` → el numerito de la
     barra desaparece.
   - `SeguimientoViewModel` empieza a seguirlo → "Mi pedido" se dibuja.
   - `AvisosViewModel` anota el celular para los avisos de ese pedido.
5. El repartidor sale → primera posición → el backend anuncia
   `repartoEmpezado` → push "Tu pedido está en camino" al cliente.
6. El cliente toca la notificación → `NotificacionesRepository.tocados` →
   `NavegacionViewModel` abre "Mi pedido".

Cada flecha de "publica/anuncia" es un **Observer**; cada "→" de una capa a
la de abajo es un **comando**.
