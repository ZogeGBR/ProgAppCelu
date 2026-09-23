# FreshMarket — App de pedidos para el almacén de Don Ceferino

Proyecto base en **Flutter/Dart** para el trabajo práctico de *Programación
de Aplicaciones para Celulares*, a partir de la entrevista a Don Ceferino
(dueño de FreshMarket, almacén de barrio).

## Cómo abrir el proyecto

El repo ya incluye las carpetas `android/` e `ios/`, así que se abre directo:

1. **Android Studio** → *File → Open* → elegir esta carpeta (la que tiene el
   `pubspec.yaml`). Hacen falta los plugins **Flutter** y **Dart**.
2. Si no lo hace solo, correr `flutter pub get` (o el botón *Pub get* que
   aparece arriba del `pubspec.yaml`).
3. Elegir un emulador o celular y darle ▶ Run (o `flutter run`).

Tests: `flutter test`.

> **Ojo con la ruta en Windows:** si la carpeta tiene tildes o símbolos
> (por ej. `5° Semestre\Programación...`), el Android Gradle Plugin corta
> el build. Por eso `android/gradle.properties` tiene
> `android.overridePathCheck=true`. Además, el analizador de Dart se cuelga
> con esas rutas (el IDE deja de marcar errores). Si pasa, copiar el
> proyecto a una ruta sin tildes (por ej. `C:\dev\freshmarket`).

## Estructura

```
lib/
├── main.dart                     ← punto de entrada (AppRoot) + tema
├── models/
│   ├── producto.dart              ← modelo Producto + catálogo de ejemplo
│   ├── item_carrito.dart          ← producto + cantidad dentro del carrito
│   ├── pedido.dart                ← pedido confirmado ("foto" del carrito)
│   ├── metodo_pago.dart           ← enum Tarjeta / Mercado Pago
│   └── estado_pedido.dart         ← enum de estados del seguimiento
├── providers/
│   └── carrito_provider.dart      ← estado del carrito (ChangeNotifier)
├── utils/
│   └── formato.dart               ← formatearPrecio(): 3800 -> "$3.800"
├── widgets/
│   ├── producto_card.dart         ← tarjeta de producto (patrón callbacks)
│   └── selector_cantidad.dart     ← control − 2 + reutilizable
└── screens/
    ├── home_screen.dart           ← catálogo con búsqueda y categorías
    ├── carrito_screen.dart        ← carrito: cantidades, borrar, total
    ├── metodo_pago_screen.dart    ← resumen + elegir pago (mock)
    └── seguimiento_screen.dart    ← línea de tiempo del pedido (simulado)
test/
├── carrito_provider_test.dart     ← tests del carrito y del formato de precio
└── widget_test.dart               ← tests de pantalla (flujo completo)
```

## Cambios de la V2

- **Listo para Android Studio**: se generaron `android/` e `ios/`,
  `.gitignore` y `analysis_options.yaml`. Nombre visible: "FreshMarket".
- **Bug corregido**: el carrito se vaciaba en el `initState()` del
  seguimiento, lo que avisaba a la Home *mientras* Flutter construía la
  pantalla nueva ("setState() called during build"). Ahora el pedido se
  confirma en el botón de pagar con `CarritoProvider.confirmarPedido()`.
- **Catálogo**: buscador, filtro por categoría (`ChoiceChip`), botón
  flotante "Ver pedido · cantidad · total" y precios con separador de miles.
- **Carrito**: cambiar cantidades con − / +, deslizar para eliminar
  (`Dismissible`), vaciar con confirmación y estado vacío con acceso al
  catálogo.
- **Pago**: resumen del pedido, opciones de pago más claras y un "Procesando
  pago..." simulado de 2 s (con chequeo de `mounted` después del `await`).
- **Seguimiento**: número de pedido, línea de tiempo por etapas, resumen de
  lo pagado y botón "Hacer otro pedido" al entregarse. Al volver atrás se
  cae en el catálogo (`pushAndRemoveUntil`), no en un carrito vacío.
- **Tests**: 9 tests (unitarios del carrito + flujo completo de pantallas).

Todo sigue sin paquetes externos, con `ChangeNotifier` + `ListenableBuilder`
y el patrón de callbacks, como se vio en clase.

## De la entrevista al código

| Pedido de Don Ceferino | Dónde se resuelve |
|---|---|
| Ver el catálogo con precio del día | `models/producto.dart` + `HomeScreen` (`ListView` + `ProductoCard`) |
| Armar el pedido y pagarlo (tarjeta o Mercado Pago) | `CarritoProvider`, `CarritoScreen`, `MetodoPagoScreen` |
| Ver el reparto "como el GPS de un taxi", en todo momento | `SeguimientoScreen`, simulado por etapas con `Timer` (sin mapa real todavía — ver comentario "Punto de extensión" en el archivo) |
| Aguantar 5.000 pedidos simultáneos en diciembre sin colgarse | **No es un problema de este frontend**: depende de la infraestructura del backend/servidor (ver nota abajo) |
| "No quiero pagar servidores, que sea gratis" | Mismo punto: es una decisión de infraestructura, no de la app Flutter en sí |
| Que se vea "moderna, con buena onda" | Material 3 (`useMaterial3: true`), `ColorScheme.fromSeed`, tarjetas redondeadas, `AnimatedSwitcher`, `TweenAnimationBuilder` en el seguimiento |

## Nota para el informe (aclaración importante)

Don Ceferino pidió que la app aguante 5.000 pedidos simultáneos en
Nochebuena **sin costo de servidor**. Estos dos pedidos son incompatibles:
soportar ese volumen de tráfico concurrente requiere infraestructura
(servidores, base de datos, balanceo de carga), lo cual tiene un costo. Esta
app Flutter es el **cliente** (frontend): la capacidad de aguantar picos de
tráfico depende del backend que la sirva, que está fuera del alcance de esta
materia — vale mencionarlo explícitamente en el informe entregable, como
parte del relevamiento de requerimientos (para dejar asentado que el pedido,
tal cual está planteado, no es técnicamente viable).

## Qué NO incluye todavía (a propósito)

Para mantenerse dentro de lo dictado hasta el momento en la materia, este
proyecto **no** usa: paquetes de manejo de estado externos (`provider`,
`riverpod`, `bloc`), geolocalización/mapas reales, ni integración real de
pagos. Todo esto está mockeado o simulado, con comentarios en el código que
marcan dónde se conectaría en una próxima entrega.
