# FreshMarket — App de pedidos para el almacén de Don Ceferino

Proyecto base en **Flutter/Dart** para el trabajo práctico de *Programación
de Aplicaciones para Celulares*, a partir de la entrevista a Don Ceferino
(dueño de FreshMarket, almacén de barrio).

## Cómo abrir el proyecto

Esta carpeta contiene solo el código fuente (`pubspec.yaml` + `lib/`), que es
lo que se edita a mano. Los proyectos nativos (`android/`, `ios/`, etc.) los
genera Flutter automáticamente:

1. Creá un proyecto nuevo vacío: `flutter create freshmarket_app`
2. Reemplazá el `pubspec.yaml` generado y la carpeta `lib/` por los de esta
   entrega.
3. `flutter pub get`
4. `flutter run`

(También podés abrir esta carpeta directamente en Android Studio/VS Code y
usar **"New Flutter Project" → importar**, según qué versión del IDE tengas.)

## Estructura

```
lib/
├── main.dart                     ← punto de entrada (AppRoot)
├── models/
│   ├── producto.dart              ← modelo Producto + catálogo de ejemplo
│   ├── item_carrito.dart          ← producto + cantidad dentro del carrito
│   └── estado_pedido.dart         ← enum de estados del seguimiento
├── providers/
│   └── carrito_provider.dart      ← estado del carrito (ChangeNotifier)
├── widgets/
│   └── producto_card.dart         ← tarjeta de producto (patrón callbacks)
└── screens/
    ├── home_screen.dart           ← catálogo
    ├── carrito_screen.dart        ← carrito y total
    ├── metodo_pago_screen.dart    ← elegir tarjeta / Mercado Pago (mock)
    └── seguimiento_screen.dart    ← estados del pedido (simulado)
```

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
