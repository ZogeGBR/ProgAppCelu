# FreshMarket: explicación completa del código

Guía archivo por archivo del proyecto. Explica qué hace cada archivo, cómo se conectan entre sí y por qué está hecho así. Está pensada para entender el código de punta a punta y poder defenderlo en una presentación.

---

## Índice

1. [La idea en 1 minuto](#1-la-idea-en-1-minuto)
2. [Conceptos de Flutter que tenés que tener claros](#2-conceptos-de-flutter-que-tenés-que-tener-claros)
3. [Mapa del proyecto](#3-mapa-del-proyecto)
4. [Cómo viaja el carrito por la app (arquitectura)](#4-cómo-viaja-el-carrito-por-la-app-arquitectura)
5. [Flujo de navegación entre pantallas](#5-flujo-de-navegación-entre-pantallas)
6. [`main.dart`](#6-maindart)
7. [Modelos (`lib/models/`)](#7-modelos-libmodels)
8. [El provider: `carrito_provider.dart`](#8-el-provider-carrito_providerdart)
9. [Utilidades: `formato.dart`](#9-utilidades-formatodart)
10. [Widgets reutilizables (`lib/widgets/`)](#10-widgets-reutilizables-libwidgets)
11. [Pantallas (`lib/screens/`)](#11-pantallas-libscreens)
12. [Tests (`test/`)](#12-tests-test)
13. [Archivos de configuración y la parte Android](#13-archivos-de-configuración-y-la-parte-android)
14. [Detalles finos y posibles mejoras](#14-detalles-finos-y-posibles-mejoras)
15. [Preguntas que te pueden hacer (con respuesta)](#15-preguntas-que-te-pueden-hacer-con-respuesta)

---

## 1. La idea en 1 minuto

FreshMarket es la app de pedidos del almacén de Don Ceferino. El usuario:

1. **Mira el catálogo**, busca y filtra por categoría, y agrega productos.
2. **Revisa el carrito**: cambia cantidades, desliza para borrar o vacía todo.
3. **Elige cómo pagar** (Tarjeta o Mercado Pago). El pago es simulado y tarda 2 segundos.
4. **Sigue el pedido** en una línea de tiempo que avanza sola cada 3 segundos: Recibido → Preparando → En camino → Entregado.

Decisiones de fondo, todas a propósito para respetar lo que se vio en la materia:

- **Sin paquetes externos.** Solo `flutter` y `cupertino_icons`. No se usa `provider`, `riverpod` ni `intl`.
- **El estado compartido** (el carrito) vive en una clase que extiende `ChangeNotifier` y se escucha con `ListenableBuilder`.
- **El estado local** de cada pantalla (la búsqueda, el método de pago elegido, la etapa del pedido) se maneja con `setState()`.
- **Patrón de callbacks:** los widgets hijos no modifican el carrito. Avisan al padre con funciones (`onAgregar`, `onQuitar`…) y el padre decide qué hacer.
- **Datos en memoria:** el catálogo es una lista fija. No hay base de datos ni API.

---

## 2. Conceptos de Flutter que tenés que tener claros

Antes de ver los archivos, estos son los conceptos que aparecen todo el tiempo.

### Widget

En Flutter **todo es un widget**: un texto, un botón, un padding, una pantalla entera. Los widgets son **inmutables**, es decir que no cambian. Cuando algo tiene que cambiar en pantalla, Flutter **reconstruye** el widget llamando de nuevo a su método `build()`.

### `StatelessWidget` vs `StatefulWidget`

| | `StatelessWidget` | `StatefulWidget` |
|---|---|---|
| ¿Tiene datos que cambian? | No | Sí, en su objeto `State` |
| ¿Cómo se redibuja? | Cuando el padre lo reconstruye | Cuando llamás `setState()` (o cambia el padre) |
| Ejemplos en el proyecto | `ProductoCard`, `SelectorCantidad`, `CarritoScreen` | `AppRoot`, `HomeScreen`, `MetodoPagoScreen`, `SeguimientoScreen` |

Un `StatefulWidget` se divide en dos clases:

- La clase del widget (`HomeScreen`), que es inmutable y recibe parámetros.
- La clase del estado (`_HomeScreenState`), que **sobrevive a los rebuilds** y guarda los datos que cambian.

Desde el `State` se accede a los parámetros del widget con `widget.algo`, por ejemplo `widget.carrito`.

### Ciclo de vida del `State`

```
createState()  →  initState()  →  build()  →  (setState → build)*  →  dispose()
```

- **`initState()`** se ejecuta **una sola vez**, al crearse. Se usa para inicializar cosas como el carrito o el Timer.
- **`build()`** se ejecuta muchas veces y tiene que ser rápido y sin efectos secundarios.
- **`dispose()`** se ejecuta al destruirse. Ahí se limpia lo que haya quedado abierto: cancelar Timers, hacer `dispose` de notifiers.

### `setState()`

Le dice a Flutter: "cambié un dato de este State, volvé a llamar a `build()`". **Solo redibuja ese widget y sus hijos.** Sirve para estado **local** de una pantalla.

### `ChangeNotifier` + `notifyListeners()` + `ListenableBuilder`

Para datos que **varias pantallas** necesitan a la vez, como el carrito, `setState()` no alcanza porque es local a un State. La solución que se usa acá:

- `CarritoProvider extends ChangeNotifier`: es un objeto que **avisa** cuando cambia, llamando a `notifyListeners()`.
- `ListenableBuilder(listenable: carrito, builder: ...)`: un widget que **escucha** ese objeto y, cada vez que avisa, vuelve a ejecutar su `builder`.

Es el patrón Observer: el carrito es el "observado" y los `ListenableBuilder` son los "observadores".

### Callbacks (`VoidCallback`)

`VoidCallback` es simplemente el tipo `void Function()`, una función sin parámetros que no devuelve nada. El padre le pasa una función al hijo, y el hijo la llama cuando pasa algo (por ejemplo, cuando tocan un botón). Así el hijo **no necesita saber** que existe un carrito.

### `Navigator` (navegación entre pantallas)

Las pantallas se apilan como una **pila de platos**:

- `Navigator.push(context, MaterialPageRoute(builder: ...))` pone una pantalla arriba.
- `Navigator.pop(context)` saca la de arriba y vuelve a la anterior.
- `Navigator.pushAndRemoveUntil(...)` pone una pantalla y saca de la pila todas las de abajo hasta que se cumpla una condición.

### `BuildContext`

Es la "ubicación" de un widget dentro del árbol. Se usa para buscar cosas de más arriba: `Theme.of(context)` (los colores y estilos), `Navigator.of(context)` (la pila de pantallas) y `ScaffoldMessenger.of(context)` (los snackbars).

### `mounted`

Es una propiedad del `State` que vale `true` mientras la pantalla existe. **Después de un `await` o dentro de un Timer**, la pantalla puede haberse cerrado. Por eso se chequea `if (!mounted) return;` antes de usar `context` o `setState`.

### `const`

Marcar un widget como `const` le dice a Dart que ese objeto se crea **una sola vez en compilación** y se reutiliza. Así Flutter no lo vuelve a crear en cada rebuild. Por eso aparecen tantos `const Text(...)` y `const SizedBox(...)`.

---

## 3. Mapa del proyecto

```
Proyecto/
├── pubspec.yaml                 ← "package.json" de Flutter: nombre, versión, dependencias
├── pubspec.lock                 ← versiones exactas resueltas (no se edita a mano)
├── analysis_options.yaml        ← reglas del analizador de código (lints)
├── README.md                    ← resumen del proyecto
├── lib/                         ← TODO el código de la app
│   ├── main.dart                ← arranque + tema + creación del carrito
│   ├── models/                  ← "qué datos existen" (clases puras, sin UI)
│   │   ├── producto.dart
│   │   ├── item_carrito.dart
│   │   ├── pedido.dart
│   │   ├── metodo_pago.dart
│   │   └── estado_pedido.dart
│   ├── providers/
│   │   └── carrito_provider.dart  ← "cómo cambian los datos compartidos"
│   ├── utils/
│   │   └── formato.dart         ← funciones sueltas de ayuda
│   ├── widgets/                 ← piezas de UI reutilizables
│   │   ├── producto_card.dart
│   │   └── selector_cantidad.dart
│   └── screens/                 ← las 4 pantallas
│       ├── home_screen.dart
│       ├── carrito_screen.dart
│       ├── metodo_pago_screen.dart
│       └── seguimiento_screen.dart
├── test/                        ← tests automáticos
│   ├── carrito_provider_test.dart
│   └── widget_test.dart
├── android/                     ← proyecto nativo Android (lo genera Flutter)
└── ios/                         ← proyecto nativo iOS (lo genera Flutter)
```

**Regla de dependencias** (quién importa a quién):

```
screens  ──►  widgets  ──►  models
   │              │            ▲
   ├──►  providers ───────────┘
   └──►  utils
```

Los **modelos no importan nada de UI**, salvo `material.dart` para los `IconData` de los enums. Las **pantallas** son las que juntan todo.

---

## 4. Cómo viaja el carrito por la app (arquitectura)

Hay **un solo** `CarritoProvider` para toda la app. Se crea en `AppRoot` y se pasa **por constructor** de pantalla en pantalla. A eso se le dice *prop drilling*.

```
AppRoot (crea _carrito UNA vez en initState)
   │  HomeScreen(carrito: _carrito)
   ▼
HomeScreen ──push──► CarritoScreen(carrito: widget.carrito)
                         │
                         └──push──► MetodoPagoScreen(carrito: carrito)
                                        │  carrito.confirmarPedido(...) → Pedido
                                        └──pushAndRemoveUntil──► SeguimientoScreen(pedido: pedido)
                                                                  (ya NO recibe el carrito)
```

Como todas las pantallas reciben **el mismo objeto**, cuando `CarritoScreen` suma una yerba, `HomeScreen` (que sigue viva abajo en la pila) también se entera. Su `ListenableBuilder` escucha al mismo carrito, así que el badge del ícono y el botón flotante quedan actualizados cuando volvés.

**¿Por qué el seguimiento recibe un `Pedido` y no el carrito?** Porque al pagar el carrito se **vacía**. El `Pedido` es una "foto" de lo que se compró, independiente del carrito.

---

## 5. Flujo de navegación entre pantallas

Así queda la pila de pantallas en cada momento (la de más a la derecha es la visible):

| Momento | Pila |
|---|---|
| Abrís la app | `[Home]` |
| Tocás el carrito | `[Home, Carrito]` |
| Tocás "Ir a pagar" | `[Home, Carrito, Pago]` |
| Termina el pago | `[Home, Seguimiento]` ← `pushAndRemoveUntil` sacó Carrito y Pago |
| "Hacer otro pedido" / atrás | `[Home]` |

Si no se hubiera usado `pushAndRemoveUntil`, al volver atrás desde el seguimiento caerías en una pantalla de pago con el carrito **vacío**, lo cual no tiene sentido.

---

## 6. `main.dart`

**Qué hace:** arranca la app, crea el carrito único y define el tema visual.

```dart
void main() {
  runApp(const AppRoot());
}
```

`main()` es el punto de entrada de cualquier programa Dart. `runApp()` le pasa a Flutter el widget raíz para que lo dibuje en pantalla.

### `AppRoot` (StatefulWidget)

```dart
class _AppRootState extends State<AppRoot> {
  late final CarritoProvider _carrito;

  @override
  void initState() {
    super.initState();
    _carrito = CarritoProvider();
  }

  @override
  void dispose() {
    _carrito.dispose();
    super.dispose();
  }
```

- **¿Por qué Stateful si no cambia nada en pantalla?** Porque el carrito tiene que crearse **una sola vez** y vivir toda la app. Si se creara dentro del `build()` de un `StatelessWidget`, cada rebuild crearía un carrito nuevo y vacío, y perderías todo. El `State` sobrevive a los rebuilds; el widget no.
- **`late final`**:
  - `late` quiere decir "lo inicializo después, no en la declaración". Acá se inicializa en `initState`.
  - `final` quiere decir "una vez asignado, no cambia".
- **`dispose()`**: el `ChangeNotifier` guarda una lista de listeners, y al cerrarse la app se libera. Fijate el orden: primero se limpia lo propio y **al final** se llama a `super.dispose()`. En `initState` es al revés: **primero** `super.initState()`.

### El tema (`ThemeData`)

```dart
final colorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF2E7D32), // verde
  brightness: Brightness.light,
);
```

- `ColorScheme.fromSeed` genera **toda una paleta** de Material 3 (primary, primaryContainer, surface, outline, error…) a partir de un solo color "semilla". Por eso en las pantallas se ven cosas como `colorScheme.primaryContainer` sin que nadie haya definido ese color a mano.
- `0xFF2E7D32` es un color en hexadecimal: `FF` es la opacidad (opaco) y `2E7D32` es el verde.
- `useMaterial3: true` activa el diseño Material 3, el más moderno. Responde al pedido de que se vea "moderna, con buena onda".
- `cardTheme`, `filledButtonTheme` y `appBarTheme` definen estilos **globales**. Todas las `Card` de la app salen sin sombra (`elevation: 0`), con bordes de 16 px y un borde finito. Los botones rellenos salen con bordes de 12 px. Así no hay que repetir el estilo en cada pantalla.
- `debugShowCheckedModeBanner: false` saca la cintita roja de "DEBUG" de la esquina.
- `home: HomeScreen(carrito: _carrito)` es la primera pantalla, y acá arranca el *prop drilling* del carrito.

---

## 7. Modelos (`lib/models/`)

Los modelos son **clases de datos**. Representan "cosas" del negocio y no dibujan nada.

### 7.1 `producto.dart`

```dart
class Producto {
  final String id;
  final String nombre;
  final double precio;
  final String categoria;
  final String emoji;

  const Producto({ required this.id, ... });
}
```

- Todos los campos son `final`, así que un producto **no cambia** una vez creado. Es inmutable.
- El constructor es `const`, lo que permite crear productos constantes en compilación.
- `required this.id` es un **parámetro nombrado obligatorio**: se usa como `Producto(id: 'p1', nombre: ...)`. Es más legible que los parámetros posicionales.
- `emoji` se usa como "imagen" del producto para no tener que manejar archivos de imagen (assets).

**`catalogoFreshMarket`** es una lista global con 8 productos de ejemplo, de 6 categorías: Almacén, Lácteos, Panadería, Verdulería, Bebidas y Limpieza. Hace de "base de datos" en memoria. En una versión real vendría de una API.

> El `id` es clave: el carrito compara productos **por id** (`item.producto.id == producto.id`), no por referencia de objeto.

### 7.2 `item_carrito.dart`

```dart
class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}
```

- Une un **producto** con **cuántos** se pidieron.
- `cantidad` **no** es `final` porque cambia cuando sumás o restás.
- `this.cantidad = 1` es un parámetro opcional con valor por defecto 1.
- `subtotal` es un **getter**: se usa como `item.subtotal` (sin paréntesis) y se **calcula** cada vez, no se guarda. La sintaxis `=>` es una forma corta de escribir `{ return ...; }`.

### 7.3 `pedido.dart`

```dart
class Pedido {
  final int numero;
  final List<ItemCarrito> items;
  final double total;
  final MetodoPago metodoPago;
  final DateTime fecha;
  ...
  int get cantidadProductos =>
      items.fold(0, (total, item) => total + item.cantidad);
}
```

- Representa un pedido **ya pagado**. Es la "foto" del carrito en el momento de pagar.
- Guarda el `total` ya calculado, que no cambia aunque después cambien los precios.
- **`fold`** recorre la lista acumulando un valor. Arranca en `0` y, por cada ítem, hace `total + item.cantidad`. Es la forma funcional de escribir:
  ```dart
  var total = 0;
  for (final item in items) total += item.cantidad;
  ```
  Cuidado: en `fold`, el `total` del lambda es el **acumulador**, no el campo `total` de la clase. Se llaman igual pero son cosas distintas.

### 7.4 `metodo_pago.dart`

```dart
enum MetodoPago { tarjeta, mercadoPago }

extension MetodoPagoInfo on MetodoPago {
  String get nombre { switch (this) { ... } }
  IconData get icono { switch (this) { ... } }
}
```

- Un **`enum`** es un tipo con un conjunto **cerrado** de valores. Un método de pago solo puede ser `tarjeta` o `mercadoPago`; no hay forma de que sea otra cosa ni un string mal escrito.
- Una **`extension`** le **agrega** getters o métodos a un tipo que ya existe. Así se puede escribir `MetodoPago.tarjeta.nombre` → `'Tarjeta'`.
- El `switch (this)` cubre **todos** los casos del enum. Si mañana agregás `efectivo` y te olvidás de manejarlo, Dart **no compila**. Eso es una ventaja de seguridad.
- `MetodoPago.values` es la lista de todos los valores, y se usa en la pantalla de pago para dibujar las opciones.

### 7.5 `estado_pedido.dart`

```dart
enum EstadoPedido { recibido, enPreparacion, enCamino, entregado }
```

Mismo patrón que el anterior, con 4 getters en la extension:

| Estado | `titulo` | `descripcion` | `icono` | `progreso` |
|---|---|---|---|---|
| `recibido` | Pedido recibido | Don Ceferino ya vio tu pedido. | 🧾 `receipt_long` | 0.25 |
| `enPreparacion` | Preparando tu pedido | Están armando tu bolsa en el almacén. | 🏪 `storefront` | 0.5 |
| `enCamino` | En camino | El repartidor va para tu casa. | 🛵 `delivery_dining` | 0.75 |
| `entregado` | ¡Entregado! | Que lo disfrutes. | ✅ `check_circle` | 1.0 |

- El **orden** de declaración importa: cada valor tiene un `.index` (0, 1, 2, 3). El seguimiento usa ese índice para avanzar al siguiente estado y para saber qué etapas ya se completaron.
- `progreso` va de 0 a 1 porque es lo que espera el `LinearProgressIndicator`.
- Esto **simula** el "GPS de un taxi" que pidió Don Ceferino. No hay mapa real porque todavía no se vio geolocalización en la materia.

---

## 8. El provider: `carrito_provider.dart`

Es **el corazón de la app**: guarda el carrito y es el único que lo modifica.

### Estructura (la "fórmula del apunte")

```
dato PRIVADO  ──►  getter PÚBLICO (solo lectura)  ──►  métodos que cambian el dato + notifyListeners()
```

```dart
class CarritoProvider extends ChangeNotifier {
  final List<ItemCarrito> _items = [];
  int _proximoNumeroPedido = 1001;
```

- El **guion bajo** (`_items`) hace que el campo sea **privado al archivo**: nadie de afuera puede hacer `carrito._items.add(...)` y saltearse el `notifyListeners()`.
- `final` en la lista significa que **la variable** siempre apunta a la misma lista. El **contenido** sí puede cambiar (add, remove, clear).
- `_proximoNumeroPedido` arranca en 1001 y se incrementa en cada pedido. Por eso el primero es el `#1001`.

### Getters (lectura)

```dart
List<ItemCarrito> get items => List.unmodifiable(_items);
bool get estaVacio => _items.isEmpty;
int get cantidadTotal => _items.fold(0, (total, item) => total + item.cantidad);
double get total => _items.fold(0, (total, item) => total + item.subtotal);
```

- `List.unmodifiable(...)` devuelve una **copia de solo lectura**. Si alguien hace `carrito.items.add(x)`, tira error. Así se fuerza a pasar por los métodos.
- `cantidadTotal` es la **suma de unidades**: 2 yerbas + 1 leche = 3. No es la cantidad de renglones, que sería `items.length` = 2.
- `total` es la plata total: la suma de los subtotales.

### Métodos que modifican

**`agregarProducto(producto)`**

```dart
final index = _indiceDe(producto);
if (index >= 0) {
  _items[index].cantidad++;      // ya estaba → +1
} else {
  _items.add(ItemCarrito(producto: producto));  // nuevo → cantidad 1
}
notifyListeners();
```

Si agregás dos veces la misma yerba **no se duplica el renglón**: se suma la cantidad. Esto está testeado.

**`quitarProducto(producto)`**: resta 1, y si la cantidad era 1, saca el renglón entero. Si el producto no estaba (`index < 0`), no hace nada y **no avisa** a nadie (`return` antes del `notifyListeners`).

**`eliminarProducto(producto)`**: saca el renglón entero, sin importar la cantidad. Se usa al deslizar un ítem en el carrito.

**`cantidadDe(producto)`**: devuelve cuántas unidades hay de ese producto, o 0. La usa `HomeScreen` para decidir si mostrar "Agregar" o el selector `− 2 +`.

**`vaciarCarrito()`**: `clear()` + `notifyListeners()`.

**`confirmarPedido(metodoPago)`**: el más importante.

```dart
Pedido confirmarPedido(MetodoPago metodoPago) {
  final pedido = Pedido(
    numero: _proximoNumeroPedido++,
    items: _items
        .map((item) => ItemCarrito(producto: item.producto, cantidad: item.cantidad))
        .toList(),
    total: total,
    metodoPago: metodoPago,
    fecha: DateTime.now(),
  );
  vaciarCarrito();
  return pedido;
}
```

1. `_proximoNumeroPedido++` es un **post-incremento**: usa el valor actual (1001) y **después** lo sube a 1002.
2. `.map(...).toList()` crea **copias nuevas** de cada `ItemCarrito`. Si se guardaran los mismos objetos y después se tocaran en el carrito, el pedido cambiaría también. Así el pedido queda congelado.
3. Calcula el `total` **antes** de vaciar, porque si no daría 0.
4. Vacía el carrito y devuelve el pedido.

> **Bug que se corrigió en la V2 (importante para explicar):** antes el carrito se vaciaba en el `initState()` de `SeguimientoScreen`. Vaciar llama a `notifyListeners()`, que le pide a `HomeScreen` que se redibuje **mientras Flutter estaba construyendo** la pantalla nueva. Eso tira el error *"setState() called during build"*. La solución fue vaciarlo en `confirmarPedido`, que se llama desde el **botón de pagar**, o sea desde un evento del usuario y no durante un build.

**`_indiceDe(producto)`** es un helper privado. `indexWhere` devuelve la posición del primer elemento que cumple la condición, o **-1** si no lo encuentra. Por eso se pregunta `index >= 0`.

---

## 9. Utilidades: `formato.dart`

```dart
String formatearPrecio(double precio) {
  final digitos = precio.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return '\$$buffer';
}
```

Convierte `3800` → `"$3.800"`, al estilo argentino con **punto** de miles.

**Cómo funciona, paso a paso con 1234567:**

- `digitos = "1234567"` (largo 7).
- Para cada posición `i`, `digitos.length - i` dice **cuántos dígitos quedan desde ahí hasta el final**. Si ese número es múltiplo de 3 (y no es el primer dígito), va un punto antes.

| i | dígito | quedan (7−i) | ¿%3==0? | buffer |
|---|---|---|---|---|
| 0 | 1 | 7 | — (i=0) | `1` |
| 1 | 2 | 6 | sí | `1.2` |
| 2 | 3 | 5 | no | `1.23` |
| 3 | 4 | 4 | no | `1.234` |
| 4 | 5 | 3 | sí | `1.234.5` |
| 5 | 6 | 2 | no | `1.234.56` |
| 6 | 7 | 1 | no | `1.234.567` |

- `StringBuffer` sirve para armar strings de a pedazos sin crear un string nuevo en cada concatenación.
- `'\$$buffer'`: `\$` es un signo `$` literal (escapado, porque `$` en Dart sirve para interpolar). Después, `$buffer` interpola el contenido. El resultado es `$1.234.567`.
- `precio.round()` redondea, así que los centavos se pierden. Está bien porque los precios son enteros.
- Se hizo a mano para no agregar el paquete `intl`.

---

## 10. Widgets reutilizables (`lib/widgets/`)

### 10.1 `selector_cantidad.dart`: el control `− 2 +`

```dart
class SelectorCantidad extends StatelessWidget {
  final int cantidad;
  final VoidCallback onSumar;
  final VoidCallback onRestar;
```

- **Stateless**: no guarda la cantidad, la **recibe**. Cuando tocan + o −, **avisa** con el callback. El que decide qué pasa es el padre, que llama al carrito.
- Se usa en **dos lugares**: en `ProductoCard` (catálogo) y en `_ItemCarritoTile` (carrito). Para eso se separó en su propio archivo.
- Detalle de UX: si la cantidad es 1, el botón de restar muestra un **tachito** (`delete_outline`) en vez de un `−`, porque restar en 1 saca el producto.

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
  child: Text('$cantidad', key: ValueKey(cantidad), ...),
),
```

- `AnimatedSwitcher` anima el cambio entre un hijo viejo y uno nuevo. Acá hace un efecto de "zoom" del número.
- **La `key` es clave** (literalmente). `AnimatedSwitcher` solo anima si detecta que el hijo es **otro** widget. Dos `Text` son del mismo tipo, así que sin la key no se daría cuenta. Con `ValueKey(cantidad)`, cuando cambia el número cambia la key y anima.
- `mainAxisSize: MainAxisSize.min` hace que el `Row` ocupe solo lo que necesita y no todo el ancho.

### 10.2 `producto_card.dart`: la tarjeta del catálogo

```dart
class ProductoCard extends StatelessWidget {
  final Producto producto;
  final int cantidadEnCarrito;
  final VoidCallback onAgregar;
  final VoidCallback onQuitar;
```

**Patrón de callbacks del apunte** (como `ShoppingListItem` con `onCartChanged`): la tarjeta **no conoce el carrito**. Solo recibe un número (`cantidadEnCarrito`) y dos funciones. Ventajas:

- Es **reutilizable**: la podrías usar con otra lógica.
- Es **fácil de testear**.
- El estado vive en un solo lugar.

Estructura visual:

```
Card
└── Padding
    └── Row
        ├── Container 56×56 (fondo verde claro, bordes redondeados) con el emoji
        ├── SizedBox(width: 12)                      ← separador
        ├── Expanded → Column: nombre (negrita) / categoría (gris) / precio (verde, grande)
        ├── SizedBox(width: 8)
        └── cantidadEnCarrito == 0 ? botón "Agregar" : SelectorCantidad
```

- **`Expanded`** hace que la columna del medio ocupe **todo el espacio sobrante** del `Row`, y empuja el botón a la derecha.
- `primaryContainer.withAlpha(120)` usa el color del tema con transparencia (alpha 120 de 255).
- `theme.textTheme.bodySmall?.copyWith(...)` toma un estilo del tema y le cambia solo el color. El `?.` es por si el estilo es `null`.
- El **operador ternario** `condición ? A : B` decide qué widget mostrar.

---

## 11. Pantallas (`lib/screens/`)

### 11.1 `home_screen.dart`: catálogo

**Stateful**, porque tiene estado **propio** (la categoría elegida y el texto de búsqueda), que a ninguna otra pantalla le importa. Para eso alcanza con `setState()`.

```dart
static const _todas = 'Todas';
String _categoriaSeleccionada = _todas;
String _busqueda = '';
```

#### Las categorías

```dart
List<String> get _categorias => [
  _todas,
  ...{for (final p in catalogoFreshMarket) p.categoria},
];
```

- `{for (...) p.categoria}` es un **set literal** con un `for` adentro (*collection for*). Un **Set no tiene repetidos**, así que cada categoría aparece una vez. Además, el Set de Dart conserva el orden de inserción.
- `...` es el **spread operator**: "desparrama" los elementos del Set dentro de la lista.
- Resultado: `['Todas', 'Almacén', 'Lácteos', 'Panadería', 'Verdulería', 'Bebidas', 'Limpieza']`.
- Las categorías **salen solas del catálogo**: si agregás un producto con una categoría nueva, aparece el chip automáticamente.

#### El filtro

```dart
List<Producto> get _productosFiltrados {
  final texto = _busqueda.trim().toLowerCase();
  return catalogoFreshMarket.where((producto) {
    final coincideCategoria = _categoriaSeleccionada == _todas ||
        producto.categoria == _categoriaSeleccionada;
    final coincideTexto =
        texto.isEmpty || producto.nombre.toLowerCase().contains(texto);
    return coincideCategoria && coincideTexto;
  }).toList();
}
```

- `where` filtra: se queda con los elementos para los que la función devuelve `true`.
- `trim()` saca espacios de los costados y `toLowerCase()` hace que la búsqueda **no distinga mayúsculas**.
- Tienen que cumplirse **las dos** condiciones (`&&`): categoría y texto.

#### El `build()` y sus partes

1. **AppBar**: título de dos líneas ("FreshMarket" / "El almacén de Don Ceferino") y, a la derecha, el ícono del carrito con un **`Badge`** (el circulito con el número).
   - El `IconButton` está envuelto en un `ListenableBuilder` que escucha al carrito, así que **solo el ícono** se redibuja cuando cambia el carrito.
   - `isLabelVisible: carrito.cantidadTotal > 0` esconde el badge si no hay nada.
2. **Buscador**: un `TextField` con `onChanged: (texto) => setState(() => _busqueda = texto)`. Cada tecla actualiza el estado y redibuja la lista filtrada.
3. **Chips de categoría**: un `ListView` **horizontal** (`scrollDirection: Axis.horizontal`) dentro de un `SizedBox(height: 48)`. Un ListView horizontal necesita una altura fija porque, si no, no sabe cuánto medir. Cada chip es un `ChoiceChip` con `selected:` y `onSelected:`.
4. **Lista de productos**:
   - Si no hay resultados → `_SinResultados` (ícono de lupa tachada + mensaje).
   - Si hay → `ListenableBuilder` + `ListView.builder`.
   - **`ListView.builder`** construye los ítems **a demanda**, solo los que se ven en pantalla. Es eficiente para listas largas. Recibe `itemCount` y un `itemBuilder(context, index)`.
   - `padding: bottom: 96` deja espacio para que el botón flotante no tape la última tarjeta.
   - Acá se conectan los callbacks: `onAgregar: () => carrito.agregarProducto(producto)`.
5. **Botón flotante** "Ver pedido · 3 · $9.100":
   - `FloatingActionButton.extended` es un FAB con ícono **y** texto.
   - `centerFloat` lo centra abajo.
   - Si el carrito está vacío devuelve `SizedBox.shrink()`, un widget de tamaño 0 que sirve para "no mostrar nada".

> **¿Por qué hay varios `ListenableBuilder` y no uno solo envolviendo toda la pantalla?** Por eficiencia: cuando cambia el carrito solo se redibujan las partes que dependen de él (el badge, la lista y el FAB), no el buscador ni los chips.

`_abrirCarrito()` hace `Navigator.push` a `CarritoScreen`, pasándole `widget.carrito` (el `widget.` es porque estamos dentro del `State`).

**`_SinResultados`**: clase privada (empieza con `_`) que solo se usa en este archivo.

### 11.2 `carrito_screen.dart`: el carrito

**Stateless**: no tiene estado propio. Todo lo que muestra sale del carrito, y escucha sus cambios envolviendo **todo el `Scaffold`** en un `ListenableBuilder`. Acá sí tiene sentido, porque casi todo depende del carrito: la lista, el total, el botón de vaciar y el estado vacío.

#### Partes

- **AppBar** "Tu pedido", con botón de **vaciar** (`delete_sweep_outlined`) que solo aparece si hay algo. Fijate el **`if` dentro de una lista**: `actions: [ if (!carrito.estaVacio) IconButton(...) ]` (*collection if*).
- **Body**: `carrito.estaVacio ? const _CarritoVacio() : ListView.builder(...)`.
- **bottomNavigationBar**: `_ResumenTotal`, o `null` si está vacío.

#### `_confirmarVaciar(context)`: diálogo de confirmación

```dart
final confirmado = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    ...
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vaciar')),
    ],
  ),
);
if (confirmado == true) carrito.vaciarCarrito();
```

- `showDialog` **devuelve un `Future`**: con `await` se espera a que el usuario elija.
- Un diálogo es **una ruta más** del Navigator. `Navigator.pop(context, true)` lo cierra **y devuelve** `true`.
- Se compara `== true` (y no solo `if (confirmado)`) porque `confirmado` es `bool?`: si el usuario toca afuera del diálogo, vuelve `null`.

#### `_ItemCarritoTile`: un renglón deslizable

```dart
Dismissible(
  key: ValueKey(item.producto.id),
  direction: DismissDirection.endToStart,
  onDismissed: (_) => onEliminar(),
  background: Container(... color: errorContainer, child: Icon(delete_outline)),
  child: ListTile(...),
)
```

- **`Dismissible`** permite **deslizar para borrar**. `endToStart` significa de derecha a izquierda.
- **Necesita una `key` única** para saber qué elemento se descartó. Por eso se usa el id del producto.
- `background` es lo que se ve "detrás" mientras deslizás: fondo rojizo con un tacho.
- `ListTile` es un renglón estándar de Material con `leading` (izquierda: el emoji), `title`, `subtitle` ("$3.800 c/u · $7.600") y `trailing` (derecha: el `SelectorCantidad`).
- Al eliminar se muestra un **SnackBar** (el cartelito de abajo) con `ScaffoldMessenger.of(context).showSnackBar(...)`.

#### `_ResumenTotal`

- `SafeArea` evita que el contenido quede tapado por la barra de gestos del celular.
- Muestra "Total (N productos)" y el monto, más el botón **"Ir a pagar"**, que hace `push` a `MetodoPagoScreen`.
- `CrossAxisAlignment.stretch` hace que el botón ocupe todo el ancho.

#### `_CarritoVacio`

Ícono de canasta + "Todavía no agregaste productos." + botón **"Ir al catálogo"**, que hace `Navigator.pop` porque el catálogo está justo abajo en la pila.

### 11.3 `metodo_pago_screen.dart`: elegir pago y "pagar"

**Stateful**, con dos datos locales:

```dart
MetodoPago _metodoSeleccionado = MetodoPago.tarjeta;  // arranca en tarjeta
bool _procesando = false;                             // ¿está "pagando"?
```

Son locales porque a ninguna otra pantalla le importan.

#### `_pagar()`: el flujo de pago (async)

```dart
Future<void> _pagar() async {
  setState(() => _procesando = true);           // 1. mostrar "Procesando..."
  await Future.delayed(const Duration(seconds: 2));  // 2. simular la pasarela
  if (!mounted) return;                          // 3. ¿sigue existiendo la pantalla?
  final pedido = widget.carrito.confirmarPedido(_metodoSeleccionado);  // 4. confirmar
  Navigator.pushAndRemoveUntil(                  // 5. ir al seguimiento
    context,
    MaterialPageRoute(builder: (context) => SeguimientoScreen(pedido: pedido)),
    (route) => route.isFirst,
  );
}
```

- **`async` / `await`**: `Future.delayed` espera 2 segundos **sin congelar la app**. Mientras tanto se sigue dibujando el spinner.
- **`if (!mounted) return;`**: durante esos 2 segundos la pantalla podría haberse cerrado. Usar `context` de una pantalla muerta da error. En la práctica eso no puede pasar porque el `PopScope` bloquea el "atrás", pero es una buena práctica obligatoria después de un `await`.
- **`pushAndRemoveUntil(..., (route) => route.isFirst)`**: pone el seguimiento y **saca todas las rutas de abajo hasta llegar a la primera** (el catálogo). La pila queda `[Home, Seguimiento]`.

#### `PopScope`

```dart
PopScope(
  canPop: !_procesando,
  child: Scaffold(...),
)
```

Mientras se procesa el pago, **bloquea el botón "atrás"** de Android y la flecha del AppBar. Así nadie se va a la mitad del pago.

#### El cuerpo

- **Card "Resumen"**: un `for` dentro de la lista de children (`for (final item in carrito.items) Padding(...)`) arma un renglón por producto, "2 × Yerba mate 1kg ... $7.600". Después van un `Divider` y el "Total a pagar".
- **"¿Cómo querés pagar?"**: un `_OpcionPago` por cada valor de `MetodoPago.values`.
  - `onTap: _procesando ? null : () => setState(...)`. En Flutter, **pasar `null` como callback desactiva** el widget, así que durante el pago no se puede cambiar el método.
- **Botón de abajo**:
  - `onPressed: _procesando ? null : _pagar` también se desactiva mientras procesa. Así se evita el **doble pago** por tocar dos veces.
  - El texto cambia: normalmente dice "Pagar $9.100 con Tarjeta" y, mientras procesa, muestra un `CircularProgressIndicator` + "Procesando pago...".
  - Ojo: se pasa `_pagar` **sin paréntesis**. Se pasa **la función**, no se ejecuta en ese momento.

#### `_OpcionPago`

Una `Card` que cambia según `seleccionado`: fondo `primaryContainer`, borde verde de 2 px y radio lleno (`radio_button_checked`) si está elegida; si no, borde gris de 1 px y radio vacío. Funciona como un "radio button" hecho a mano, con mejor aspecto.

> **¿Por qué esta pantalla no tiene `ListenableBuilder`?** Porque el carrito **no cambia** mientras estás acá. No hay botones que lo modifiquen; el único cambio es `confirmarPedido`, y justo después te vas de la pantalla.

### 11.4 `seguimiento_screen.dart`: seguimiento del pedido

**Stateful**. Recibe el `Pedido` (no el carrito) y guarda:

```dart
EstadoPedido _estado = EstadoPedido.recibido;
Timer? _timer;
bool get _entregado => _estado == EstadoPedido.entregado;
```

`Timer?` lleva el `?` porque es **nullable**: puede ser `null` (Null Safety de Dart).

#### El Timer

```dart
@override
void initState() {
  super.initState();
  _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
    if (!mounted) return;
    setState(() {
      _estado = _siguienteEstado(_estado);
    });
    if (_entregado) {
      timer.cancel();
    }
  });
}
```

- `Timer.periodic` ejecuta la función **cada 3 segundos**. Viene de `dart:async`, por eso el import.
- Cada tick avanza un estado: 0 s → Recibido, 3 s → Preparando, 6 s → En camino, 9 s → Entregado. Al llegar a Entregado, el timer **se cancela solo**.
- `_siguienteEstado` usa `.index + 1` y `EstadoPedido.values[...]`. Si ya está en el último, se queda ahí.

```dart
@override
void dispose() {
  _timer?.cancel();
  super.dispose();
}
```

- **Fundamental:** si salís de la pantalla antes de que termine, el Timer seguiría corriendo para siempre (*memory leak*) e intentaría hacer `setState` sobre una pantalla muerta. Por eso se cancela en `dispose()`.
- `_timer?.cancel()`: el `?.` llama a `cancel()` solo si `_timer` no es null.

#### El `build()`

1. **AppBar** con "Pedido #1001".
2. **Ícono grande animado**: un `CircleAvatar` con el ícono del estado actual dentro de un `AnimatedSwitcher` con `ScaleTransition`. La `key: ValueKey(_estado)` hace que anime al cambiar de estado (es el mismo truco que en el selector de cantidad).
   - Ahí hay un comentario **"Punto de extensión"**: es el lugar donde iría un mapa real (`google_maps_flutter`) con la ubicación del repartidor (Tobías o Male).
3. **Título + descripción** del estado, también con `AnimatedSwitcher` (fade, que es la transición por defecto).
4. **Barra de progreso animada**:
   ```dart
   TweenAnimationBuilder<double>(
     tween: Tween(begin: 0, end: _estado.progreso),
     duration: const Duration(milliseconds: 500),
     curve: Curves.easeInOut,
     builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 10),
   )
   ```
   - `TweenAnimationBuilder` anima un número de un valor a otro. Cuando cambia el `end` (0.25 → 0.5), anima **desde el valor actual** hasta el nuevo en 500 ms, con aceleración suave (`easeInOut`). El `begin: 0` solo se usa la primera vez.
   - `ClipRRect` redondea los bordes de la barra.
5. **Línea de tiempo**: un `_EtapaTimeline` por cada estado, con `completada: etapa.index <= _estado.index` (todas las etapas hasta la actual inclusive van en verde).
6. **Card resumen**: Productos / Pagado con / Total (en negrita), usando `_FilaResumen`.
7. **Botón de abajo**:
   - Si no se entregó: `OutlinedButton` "Seguir comprando".
   - Si se entregó: `FilledButton.icon` "Hacer otro pedido".
   - Los dos hacen `Navigator.pop`, y como abajo está el catálogo (gracias al `pushAndRemoveUntil`), volvés ahí.

#### `_EtapaTimeline`

```
 (✓)  Pedido recibido
  │
 (✓)  Preparando tu pedido
  │
 ( )  En camino
  │
 ( )  ¡Entregado!
```

- `IntrinsicHeight` + `CrossAxisAlignment.stretch` hacen que la columna del círculo mida **lo mismo de alto que el texto**. Así la línea vertical (`Expanded(child: Container(width: 2))`) llega justo hasta el próximo círculo.
- `AnimatedContainer` anima solo el cambio de color o relleno del círculo cuando una etapa se completa.
- `if (!esUltima)` hace que el último paso no tenga línea hacia abajo.

#### `_FilaResumen`

Un renglón "etiqueta ........ valor" (`MainAxisAlignment.spaceBetween`), opcionalmente en negrita (`destacado`).

---

## 12. Tests (`test/`)

Se corren con `flutter test`. Son **9 tests** en total.

### 12.1 `carrito_provider_test.dart`: tests **unitarios**

Prueban la lógica pura, sin pantallas.

```dart
group('CarritoProvider', () {
  late CarritoProvider carrito;
  setUp(() => carrito = CarritoProvider());
  ...
});
```

- `group` agrupa tests relacionados.
- `setUp` se ejecuta **antes de cada test**, así que cada test arranca con un carrito nuevo y vacío. Los tests no se contaminan entre sí.

| Test | Qué verifica |
|---|---|
| agregar el mismo producto suma cantidad | 2 yerbas + 1 leche → 2 renglones, 3 unidades, total 9.100 |
| quitar hasta 0 saca el producto | agregar y quitar leche → carrito vacío |
| eliminarProducto saca el ítem entero | 2 yerbas, eliminar → 0 |
| confirmarPedido guarda una copia y vacía | total 5.300, 2 productos, MP, carrito vacío, y el siguiente número es +1 |
| avisa a los listeners | agregar + quitar → `notifyListeners` se llamó 2 veces |
| formatearPrecio | 0 → `$0`, 800 → `$800`, 3800 → `$3.800`, 1234567 → `$1.234.567` |

`expect(valorReal, valorEsperado)` es la **aserción**: si no coinciden, el test falla.

### 12.2 `widget_test.dart`: tests **de widgets** (de pantalla)

Arman la app en un entorno simulado y la "tocan" como un usuario.

- `tester.pumpWidget(const AppRoot())` dibuja la app.
- `find.text('Agregar')` busca widgets con ese texto. `.first` toma el primero.
- `tester.tap(...)` simula un toque.
- `tester.pump()` avanza **un frame**; `tester.pump(Duration(...))` avanza el reloj **simulado**. El test no espera de verdad 2 segundos.
- `tester.pumpAndSettle()` avanza frames hasta que terminen todas las animaciones.
- `findsOneWidget` / `findsNothing` comprueban que haya exactamente uno o ninguno.

| Test | Qué hace |
|---|---|
| Agregar actualiza el contador | Sin "Ver pedido" al inicio → tocar Agregar → aparece "Ver pedido · 1" |
| Filtro por categoría | Tocar el chip "Lácteos" → se ve la leche y no la yerba |
| **Flujo completo** | Agregar → Ver pedido → Ir a pagar → Pagar → ve "Procesando pago..." → +2 s → "Pedido #1001" → 3 ticks de 3 s → "Hacer otro pedido" → vuelve al catálogo con el carrito vacío |

---

## 13. Archivos de configuración y la parte Android

### `pubspec.yaml`

```yaml
name: freshmarket_app          # nombre del paquete (por eso los tests importan package:freshmarket_app/...)
version: 1.0.0+1               # versión visible + número de build
environment:
  sdk: '>=3.0.0 <4.0.0'        # Dart 3 (null safety obligatoria, switch exhaustivo)
dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.6      # íconos estilo iOS (viene por defecto)
dev_dependencies:              # solo para desarrollo, no van en la app final
  flutter_test: { sdk: flutter }
  flutter_lints: ^3.0.0        # reglas de estilo
flutter:
  uses-material-design: true   # incluye la fuente de íconos Material (Icons.xxx)
```

`^1.0.6` quiere decir "cualquier 1.x.x desde 1.0.6", es decir, compatibles sin cambios que rompan.

### `analysis_options.yaml`

Activa las reglas de `flutter_lints`. Son las que hacen que el IDE marque en amarillo cosas como "usá `const` acá". Se corre con `flutter analyze`.

### `pubspec.lock`

Guarda las versiones **exactas** que se descargaron, para que todos los del grupo usen las mismas. No se edita a mano.

### Carpeta `android/`

Es el proyecto nativo de Android que **envuelve** a la app Flutter. Casi todo lo genera `flutter create`. Los archivos importantes:

- **`app/src/main/kotlin/.../MainActivity.kt`**
  ```kotlin
  class MainActivity : FlutterActivity()
  ```
  Es la única pantalla nativa: una `FlutterActivity` vacía que "aloja" el motor de Flutter. Usa `io.flutter.embedding.android`, que es el **embedding v2**. Si falta este archivo, o el manifest no declara el embedding v2, Flutter tira el error **"Build failed due to use of deleted Android v1 embedding"**, que fue justo lo que pasó cuando la carpeta `android/` local estaba incompleta.
- **`app/src/main/AndroidManifest.xml`**: declara la app ante Android.
  - `android:label="FreshMarket"` es el nombre que se ve bajo el ícono.
  - `<intent-filter>` con `MAIN` + `LAUNCHER` hace que la app aparezca en el menú del celular.
  - `<meta-data android:name="flutterEmbedding" android:value="2" />` indica que es el embedding v2.
  - `windowSoftInputMode="adjustResize"` hace que, cuando aparece el teclado (por ejemplo en el buscador), la pantalla se achique en vez de quedar tapada.
- **`app/build.gradle.kts`**: configuración de compilación. Incluye el `applicationId` (`com.freshmarket.freshmarket_app`, el identificador único de la app) y las versiones de SDK, que toma de Flutter. La versión release se firma con las claves de debug, lo cual está bien para la facultad pero no para publicar.
- **`settings.gradle.kts`**: lee la ruta del SDK de Flutter desde `local.properties` y declara los plugins (Android Gradle Plugin 9.0.1, Kotlin 2.3.20).
- **`gradle.properties`**: tiene `android.overridePathCheck=true`. Sin esto, el build falla si la ruta del proyecto tiene tildes o símbolos (como `5° Semestre`).
- **`local.properties`**: rutas de **tu** PC (dónde está Flutter y el SDK de Android). **No se sube a git** porque cada uno tiene la suya.

### Carpeta `ios/`

Lo mismo pero para iPhone. Solo se puede compilar desde una Mac, así que en este proyecto está solo "por completitud".

---

## 14. Detalles finos y posibles mejoras

Cosas que no son errores pero que vale la pena conocer, por si te preguntan o querés mejorar algo.

1. **`List.unmodifiable` no protege los ítems por dentro.** La lista no se puede modificar, pero `carrito.items[0].cantidad = 99` **sí funciona**, porque `cantidad` es mutable, y encima no llamaría a `notifyListeners()`. Para blindarlo, `ItemCarrito` debería ser inmutable (con `final cantidad` y un método `copyWith`).
2. **`carrito.items` crea una copia cada vez que se llama.** En `CarritoScreen`, el `itemBuilder` hace `carrito.items[index]`, así que copia la lista por cada renglón. Con 8 productos no importa; con miles convendría guardar `final items = carrito.items;` una vez antes del `ListView`.
3. **`formatearPrecio` no maneja bien los negativos.** Cuenta el `-` como si fuera un dígito, así que `-150` da `$-.150`. No pasa en la app porque nunca hay precios negativos.
4. **El número de pedido se reinicia** al cerrar la app (vuelve a 1001), porque vive en memoria. Lo mismo pasa con el carrito. Persistirlos requeriría `shared_preferences` o una base de datos.
5. **El catálogo es fijo.** Los precios del día de Don Ceferino deberían venir de una API o base de datos para que él los pueda cambiar.
6. **Prop drilling:** pasar el carrito por constructor está bien con 4 pantallas. Con muchas más, se suele usar `InheritedWidget` o el paquete `provider` para no pasarlo a mano por todos lados.
7. **El pago y el seguimiento son simulados**: `Future.delayed` y `Timer`. Los "puntos de extensión" están comentados en el código.
8. **5.000 pedidos simultáneos sin pagar servidor**: no es un problema de esta app (el frontend) sino del backend, y además las dos cosas son incompatibles. Está explicado en el README para el informe.

---

## 15. Preguntas que te pueden hacer (con respuesta)

**¿Por qué `AppRoot` es Stateful si no cambia nada visualmente?**
Porque el `CarritoProvider` tiene que crearse una sola vez y vivir toda la app. El `State` persiste entre rebuilds; un `StatelessWidget` lo recrearía vacío.

**¿Cuándo usaron `setState` y cuándo `ChangeNotifier`?**
`setState` para el estado que importa a **una sola pantalla**: búsqueda, categoría, método de pago, "procesando", etapa del pedido. `ChangeNotifier` para el estado que comparten **varias pantallas**, que es el carrito.

**¿Qué hace `notifyListeners()`?**
Avisa a todos los que escuchan al carrito (los `ListenableBuilder`) que algo cambió, para que se redibujen.

**¿Qué es el patrón de callbacks y dónde está?**
El hijo recibe funciones del padre y las llama cuando pasa algo, sin saber qué hacen. Está en `ProductoCard` (`onAgregar`, `onQuitar`), en `SelectorCantidad` (`onSumar`, `onRestar`) y en `_ItemCarritoTile` (`onEliminar`).

**¿Por qué se chequea `mounted`?**
Porque después de un `await` o dentro de un Timer la pantalla pudo haberse cerrado, y usar `context` o `setState` en una pantalla destruida da error.

**¿Por qué se cancela el Timer en `dispose`?**
Para que no siga corriendo en memoria (memory leak) e intente actualizar una pantalla que ya no existe.

**¿Qué error arreglaron en la V2?**
"setState() called during build": el carrito se vaciaba en `initState` del seguimiento y eso notificaba a la Home mientras Flutter construía. Se movió al botón de pagar (`confirmarPedido`).

**¿Por qué el pedido guarda copias de los ítems?**
Para que sea una foto independiente: si el carrito se vacía o cambia, el pedido conserva lo que se compró.

**¿Para qué sirve la `key` en `AnimatedSwitcher` y en `Dismissible`?**
En `AnimatedSwitcher`, para que detecte que el hijo cambió y anime. En `Dismissible`, para identificar qué elemento se descartó de la lista.

**¿Qué diferencia hay entre `push`, `pop` y `pushAndRemoveUntil`?**
`push` apila una pantalla y `pop` la saca. `pushAndRemoveUntil` apila una y además saca las de abajo hasta cumplir una condición. Se usa después de pagar para que "atrás" vuelva al catálogo y no a un carrito vacío.

**¿Por qué `ListView.builder` y no `ListView` con una lista de hijos?**
Porque `builder` crea solo los ítems visibles, a medida que hacés scroll. Es más eficiente para listas largas. Para la fila de chips, que es corta, se usa `ListView` común.

**¿Cómo funciona la búsqueda?**
El `TextField` guarda el texto con `setState` en cada tecla. El getter `_productosFiltrados` filtra el catálogo con `where` por categoría **y** texto (sin distinguir mayúsculas), y la lista se redibuja.

**¿Qué hace `PopScope(canPop: !_procesando)`?**
Bloquea el botón "atrás" mientras se procesa el pago.

**¿Por qué no usaron el paquete `intl` para formatear precios?**
Para no sumar dependencias externas en esta etapa de la materia. Se hizo a mano en `formatearPrecio`.
