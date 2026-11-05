# Informe de mejoras — FreshMarket V3

Programación de Aplicaciones para Celulares · ITU

García Badiola, Zoe — Lopez, Matias — Morichetti Ramal, Ignacio

## 1. Diagnóstico de la V2

| Principio | Qué cumplía | Qué rompía |
|---|---|---|
| Código limpio | Buenos nombres en español, `enum` para estados y pagos, cláusulas de guarda, `const` | Modelos de dominio con `IconData` (importaban `material.dart`); catálogo fijo dentro del modelo; `confirmarPedido` hacía dos cosas (armar y vaciar) |
| Arquitectura en capas | `ChangeNotifier` + `ListenableBuilder`, patrón de callbacks | No había repositorios ni servicios: las pantallas tenían la lógica (filtro, pago simulado, `Timer` del seguimiento). No había inyección de dependencias |
| Future y async/await | Chequeo de `mounted` después del `await` del pago | Sin estados de carga ni de error, sin tiempo límite, sin reintento (todo era local) |
| Refactoring | 9 pruebas | Faltaban pruebas de caracterización antes de cambiar la estructura |
| Usabilidad | Material 3, buscador, chips | Navegación por pantallas apiladas (el carrito se abría desde un ícono chico); botones y letra de tamaño estándar |
| Pedidos de Don Ceferino | Catálogo, carrito, pago y seguimiento simulados | Sin mapa real, sin pago real, sin forma fácil de cargar productos |

## 2. Qué mejoramos

| Mejora | Teoría aplicada | Archivos |
|---|---|---|
| Pruebas de caracterización **antes** de tocar el código | Refactoring: red de seguridad, paso 0 | `test/caracterizacion_test.dart` |
| Reorganización en Vista → ViewModel → Repositorio → Servicio | Arquitectura en capas (MVVM) | `lib/ui/`, `lib/data/`, `lib/domain/` |
| Modelos de dominio puros, con `fromJson`/`toJson`; íconos y textos a la UI | Una pieza, una responsabilidad | `domain/models/*`, `ui/*/widgets/*_ui.dart` |
| Servicios con interfaz (`abstract interface class`) y versión real y simulada | Inyección de dependencias, `implements` | `data/services/*` |
| Un solo lugar elige las implementaciones | Inyección por constructor | `config/dependencias.dart` |
| Caché del catálogo y un reintento automático | El repositorio decide cuándo ir al servicio | `data/repositories/catalogo_repository.dart` |
| ViewModels sin `BuildContext` ni `material.dart` | Regla de capas (fragmento B del práctico) | `ui/*/view_models/*` |
| `EstadoCarga` y pasos con `enum` en cada pantalla que espera | Async: cargando / éxito / error | `ui/core/estado_carga.dart`, `PasoPago`, `PasoEscaner` |
| Tiempo límite en todas las llamadas HTTP y en la espera del pago | `timeout` + política por defecto | `api_client.dart`, `pago_repository.dart` |
| Streams con `Stream.periodic` y cancelación en `dispose` | Sin timers colgados ni pérdidas de memoria | `seguimiento_service.dart`, `*_view_model.dart` |
| Corte de señal en el seguimiento: avisa y sigue | Manejo de errores en streams | `seguimiento_view_model.dart` |
| `confirmarPedido` → `armarPedido` + `vaciarCarrito` (se vacía solo si el pago se aprueba) | Extract Function; una función, una cosa | `carrito_view_model.dart` |
| `ItemCarrito` inmutable con `copiarCon` | Evitar cambios por accidente | `domain/models/item_carrito.dart` |
| `switch` de expresión en lugar de `switch` con `return` repetido | Código más corto y exhaustivo | `*_ui.dart`, pantallas |
| Formato de precios en una utilidad de UI compartida | El ViewModel trabaja con números | `ui/core/formato.dart` |
| Constantes con nombre (`altoBotonGrande`, `primerNumeroDePedido`, `_limiteAnalisis`) | Sin números mágicos | varios |
| Lints extra: `prefer_single_quotes`, `unawaited_futures`, `use_build_context_synchronously` | Herramientas de código limpio | `analysis_options.yaml` |
| Sección "Convenciones" del README actualizada | Consistencia del equipo | `README.md` |
| 66 pruebas de la app (antes 9) | Pruebas con fakes, sin internet | `test/*` |
| El número de pedido lo asigna el servidor | Antes cada celular empezaba en #1001: dos clientes tenían el mismo número | `backend/src/pagos.js`, `pago_repository.dart` |
| Un pedido ya existente no se puede pisar | Validación en el servidor: nunca confiar en lo que manda la app | `backend/src/pagos.js` |
| Cambiar el catálogo y usar la IA exige la sesión del dueño | Antes cualquiera podía cargar productos o gastar la clave de Gemini | `backend/src/sesiones.js`, `app.js` |
| La simulación del repartidor se apaga con pagos reales | Un cliente nunca debe ver un repartidor inventado | `backend/src/seguimiento.js` |

## 3. Funcionalidades nuevas

### Mapa con el repartidor en bicicleta en tiempo real
- Pantalla "Mi pedido": cuando el pedido está **en camino**, aparece un mapa
  de **OpenStreetMap** (`flutter_map`, gratis y sin clave) con la bici y la
  casa. El mapa se centra solo en cada posición nueva y muestra los minutos
  que faltan.
- La posición llega por `SeguimientoService`: en la demo se simula un recorrido
  por el centro de Mendoza; con backend se consulta `/pedidos/:id/seguimiento`
  cada 3 s. El celular del repartidor manda su GPS a `/repartidores/posicion`
  (con clave compartida).

### Cargar producto con una foto (IA)
- En "Mi almacén" (solo para el dueño), un botón grande: **Cargar producto
  con una foto**.
- La foto viaja al backend, que la analiza con **Gemini** y devuelve nombre,
  categoría, precio sugerido, descripción y emoji. El backend limpia la
  respuesta (nunca confía en la IA tal cual).
- Don Ceferino solo revisa: el precio se puede corregir y la categoría se
  elige con botones. **Nada se guarda hasta que toca "Guardar producto".**

### Pagos con Mercado Pago
- Tres opciones grandes y claras: **tarjeta de débito, tarjeta de crédito y
  dinero en Mercado Pago**, más **efectivo al recibir**, que no pasa por
  Mercado Pago y le avisa al repartidor cuánto cobrar.
- El backend crea la preferencia de **Checkout Pro** con el Access Token (que
  nunca está en la app), **recalcula el total con sus propios precios** y
  muestra solo el medio elegido. La app abre el checkout: si la app de Mercado
  Pago está instalada se abre ahí; si no, en el navegador.
- La confirmación llega por **webhook** (con firma `x-signature` validada) y
  la app consulta el estado cada 3 s, con un límite de 5 minutos. Si se
  aprueba, recién ahí se vacía el carrito y empieza el seguimiento. Si se
  rechaza, la persona no pierde lo que había elegido.

### Navegación fácil
- Barra de abajo siempre visible con 3 botones grandes con ícono y texto:
  **Comprar · Mi carrito · Mi pedido** (+ **Mi almacén** para el dueño o
  **Repartir** para el repartidor, una vez que ingresan con su clave).
- Letra más grande, botones de 56 dp, botón "Agregar" de todo el ancho.
- Textos cortos y sin palabras técnicas ("Revisá tu conexión a internet y
  probá otra vez", "No se cobró nada").
- Todas las esperas dicen qué se está esperando y todos los errores tienen
  un botón para seguir. Se sacó el "deslizar para borrar" (difícil de
  descubrir): ahora se quita con el botón "−", que en 1 se vuelve un tacho.

### Ingreso del dueño y del repartidor
- Los clientes compran sin cuenta, a propósito: un registro sería una traba
  para personas mayores.
- El dueño y el repartidor tocan el ícono del almacén e ingresan con su clave.
  El backend devuelve una sesión firmada que vence a las 12 horas y frena a
  quien prueba muchas claves. Cada rol ve solo su sección.

### Dirección de entrega
- Al pagar se pide la calle y el número. Marcar la casa en el mapa es opcional:
  si se marca, ese es el destino que ven el cliente y el repartidor.

### Modo repartidor
- Lista de pedidos para llevar, con la dirección, lo que lleva y si hay que
  cobrar. Al salir a repartir, la app manda su GPS y el cliente lo ve en el
  mapa con los minutos estimados, hasta que toca **Ya lo entregué**.
- Funciona con la app abierta: mandar la ubicación en segundo plano queda
  pendiente.

### Mi almacén
- Don Ceferino cambia el precio del día, marca lo que no hay (el cliente ve
  "Hoy no hay" y el servidor rechaza esa compra) y borra productos.

### Base de datos
- El backend guarda productos, pedidos y posiciones en **SQLite**: al reiniciar
  el servidor no se pierde nada. Alcanza para un solo servidor.

```
Vista (Screen) ──comandos──▶ ViewModel (ChangeNotifier, solo foundation.dart)
   ▲ ListenableBuilder            │
   └──────────────────────────────┘
                                  ▼
                           Repositorio (JSON → modelo, caché, reintento, espera)
                                  ▼
                            Servicio (sin estado; real o simulado)
                                  ▼
               Backend propio (Node) ──▶ Mercado Pago · Gemini · repartidor
```

## 4. Pruebas y resultados

| Conjunto | Pruebas | Resultado |
|---|---|---|
| Backend (`cd backend && npm test`) | 27: sesiones y permisos, catálogo, total recalculado, número de pedido, validaciones, efectivo, firma del webhook, reparto, IA, datos que sobreviven a un reinicio | **27/27 pasan** |
| App: caracterización | 4 | Pasan |
| App: `CarritoViewModel` | 8 | Pasan |
| App: `CatalogoViewModel` (caché, reintento, error, filtros) | 6 | Pasan |
| App: `PagoViewModel` (aprobado, rechazado, error, sin confirmar, dirección, efectivo, número del servidor) | 10 | Pasan |
| App: `SeguimientoViewModel` (mapa, corte de señal, entregado, destino) | 5 | Pasan |
| App: `EscanerViewModel` (foto, edición, guardar, IA falla) | 5 | Pasan |
| App: `AlmacenViewModel` (precio, sin stock, borrar, error) | 6 | Pasan |
| App: `RepartoViewModel` (permisos, GPS, corte de señal, entrega) | 8 | Pasan |
| App: `SesionViewModel` (roles, clave mala, sin internet, salir) | 6 | Pasan |
| App: pantallas (flujo completo e ingreso con clave) | 8 | Pasan |

`flutter analyze` no da avisos.

**Prueba en el emulador (Pixel 7) contra el backend local, sin claves externas:**
compra con dirección y punto en el mapa, pago simulado en el navegador, pedido
en efectivo, modo repartidor con GPS, entrega, cambios del dueño vistos desde
"Comprar", carga con foto (etiqueta de ejemplo) y datos que siguen ahí después
de reiniciar el servidor.

**Sin probar:** Mercado Pago real, Gemini real, un celular físico y el webhook,
porque necesitan claves o una URL pública.

### Prueba de carga (`node scripts/carga.mjs <clientes>`)

Cada cliente simulado hace lo mismo que la app: catálogo, pedido, pago, estado
y seguimiento, todos al mismo tiempo.

| Clientes a la vez | Peticiones | Con error | Por segundo | Mediana | p95 |
|---|---|---|---|---:|---:|
| 500 | 2.500 | 0 | 730 | 631 ms | 1.021 ms |
| 5.000 | 25.000 | 9.470 (38 %) | 652 | 7.677 ms | 13.463 ms |

Son mediciones en una sola PC, con cliente y servidor en la misma máquina, sin
internet de por medio y sin esperar a Mercado Pago. Sirven para comparar y no
para prometer: parte de los errores con 5.000 puede venir del propio generador
de carga. Falta repetirlo en el servidor real.

## 5. Qué faltaría

| Pendiente | Por qué | Prioridad |
|---|---|---|
| Probar en un celular real, con Mercado Pago y Gemini reales | En el emulador se probó todo en modo simulado | Alta |
| Publicar el backend con **https** | Mercado Pago necesita una URL pública para avisar los pagos y volver a la app. Hace falta contratar un servidor | Alta |
| **Volumen de pedidos: 5.000 simultáneos sin pagar servidores** | Don Ceferino pidió 5.000 en Nochebuena sin costo, y esas dos cosas son incompatibles. Con la profesora acordamos que un almacén de barrio no llega a ese número y que el pico realista es de **hasta 500**. Hay que presentarle ese número a Don Ceferino, con el costo de un servidor chico, y medir en ese servidor (ver la prueba de carga) | Alta |
| Mandar el GPS con la app cerrada o la pantalla apagada | Hoy el repartidor tiene que dejar la app abierta; falta el permiso de ubicación en segundo plano | Media |
| Recuperar el pedido al reabrir la app | "Mi pedido" vive en memoria: si el cliente cierra la app, deja de ver el seguimiento (el pedido sigue en el servidor) | Media |
| Avisar al cliente si cambió el precio o se acabó un producto de su carrito | El servidor cobra el precio actual y rechaza lo que no hay, pero la app solo muestra un error general | Media |
| Cuentas individuales para los repartidores | Hoy todos comparten una clave, así que no se sabe quién lleva cada pedido | Media |
| Volver solo a la app después de pagar (deep link) | Hoy vuelve con una página web y la app detecta el pago consultando | Media |
| Notificaciones push ("tu pedido está en camino") | Avisar sin tener la app abierta (Firebase Cloud Messaging) | Media |
| Cantidad de stock | Hoy es "hay / no hay": alcanza para el almacén, pero no descuenta unidades | Baja |
| Guardar la foto del producto y mostrarla en el catálogo | Hoy el catálogo usa emojis | Media |
| Proveedor de mapas para producción | Los mosaicos públicos de OpenStreetMap tienen límite de uso justo; con muchos usuarios conviene MapTiler, Stadia o un caché propio | Media |
| Pruebas de usabilidad con clientes reales del almacén | Confirmar que personas mayores completan una compra sin ayuda | Media |
| Credenciales de producción de Mercado Pago y devoluciones | Hoy se prueba con credenciales de prueba; falta el flujo de reembolso | Media |
| Costos | Mercado Pago cobra comisión por venta; Gemini tiene un nivel gratis con límites; el hosting tiene costo mensual | Baja |
| Accesibilidad avanzada | Etiquetas `Semantics` para lector de pantalla y prueba con letra al 200 % | Baja |
| Publicar en Play Store | Firma, íconos y política de privacidad (usa la cámara) | Baja |
| Reescribir `EXPLICACION_CODIGO.md` archivo por archivo para la V3 | Hoy tiene una tabla de equivalencias V2 → V3 al principio | Baja |
