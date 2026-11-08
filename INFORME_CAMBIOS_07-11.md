# Informe: cambios después de la presentación a la profesora (07-11)

Programación de Aplicaciones para Celulares · ITU

García Badiola, Zoe — Lopez, Matias — Morichetti Ramal, Ignacio

Cuando le mostramos la app, la profesora marcó qué faltaba. Este informe
cuenta **qué se hizo con cada punto, por qué se hizo así y cómo**, más lo
que se corrigió al revisar el código y cómo se comprobó que todo anda.

## 1. Qué se pidió y qué se hizo

| Pedido de la profesora | Resultado | Dónde |
|---|---|---|
| Recuperar la clave | Ya estaba hecho por Zoe (06-11): código de 6 números por email. Se **corrió y verificó** (no se había podido probar) | `lib/ui/sesion/`, `backend/src/recuperacion.js` |
| Ojito para ver la contraseña | Ya estaba hecho por Zoe (`CampoClave`). Verificado con una prueba de pantalla | `lib/ui/core/widgets/campo_clave.dart` |
| **Usar mejor el Observer en todo el código** | El Observer ahora se usa **también entre la capa de datos y los ViewModels**: los repositorios publican sus cambios y los ViewModels se suscriben. Se eliminaron los 5 callbacks que encadenaban ViewModels. En el backend, un `EventEmitter` avisa los cambios de los pedidos | Sección 2 |
| **Usar y entender mejor los patrones** | Guía para el oral con cada patrón explicado sobre el código, recorridos completos y preguntas probables. Informe de teoría actualizado | `docs/GUIA_PATRONES.md`, `INFORME_TEORIA_Y_PATRONES.md` |
| **Notificaciones push con FCM** | Avisos "Nuevo pedido" (al almacén), "Tu pedido está en camino" y "Tu pedido llegó" (al cliente), con la app abierta, en segundo plano o cerrada. Al tocarlos se abre la sección. Funciona también en la demo sin backend | Sección 3, `docs/NOTIFICACIONES.md` |
| **Pasar la app a un celular** (para la EGI) | APK de release que compila, configuración de Android para red local y notificaciones, y guía paso a paso con lo que hay que probar en el celular | Sección 4, `docs/CELULAR_REAL.md` |
| **Repasar bien el código** | Revisión completa: se corrieron todas las pruebas de Zoe, se encontraron y corrigieron problemas, y se sumaron 38 pruebas en la app y 10 en el backend | Secciones 5 y 6 |

## 2. Observer en todo el código

### Qué había

El Observer ya se usaba entre la **vista y el ViewModel** (`ChangeNotifier`
con `ListenableBuilder`). Pero cuando un ViewModel tenía que enterarse de lo
que hacía otro, se los conectaba **a mano con callbacks** en `main.dart` e
`InicioScreen`:

| Callback | Qué hacía |
|---|---|
| `PagoViewModel(alAprobar: ...)` | Al aprobarse el pago, vaciaba el carrito y arrancaba el seguimiento |
| `AlmacenViewModel(alCambiarCatalogo: ...)` | Al cambiar un precio, recargaba "Comprar" |
| `EscanerViewModel(alGuardar: ...)` | Al cargar un producto con foto, recargaba "Comprar" y "Mi almacén" |
| `IngresarScreen(alIngresar: ...)` | Al entrar, cargaba "Mi almacén" o el reparto y cambiaba de sección |
| `SesionRepository(alCambiarToken: ...)` | Le pasaba el token al `ApiClient` |
| `_salir()` en `InicioScreen` | Apagaba el GPS del reparto, cerraba la sesión y volvía a "Comprar" |

**Por qué era un problema:** quien producía el cambio tenía que **conocer y
llamar** a todos los interesados. Cada pantalla nueva obligaba a acordarse
de sumarla en esos callbacks, y si alguien se olvidaba (por ejemplo, de
apagar el GPS al salir) era un bug silencioso.

### Qué se hizo

El **repositorio** (que ya era la única fuente de verdad) pasó a ser también
el **sujeto** del Observer: publica cada cambio en un `Stream`. Los
ViewModels que lo necesitan se suscriben en el constructor y se dan de baja
en `dispose()`.

| Sujeto | Publica | Observadores |
|---|---|---|
| `CatalogoRepository.cambios` | La lista de productos | "Comprar", "Mi almacén" |
| `SesionRepository.cambios` | La sesión (o `null` al salir) | `ApiClient`, barra de abajo, sesión, "Mi almacén", reparto, avisos |
| `PagoRepository.pedidosConfirmados` | Cada pedido confirmado (una sola vez) | Carrito, "Mi pedido", avisos |
| `NotificacionesRepository.recibidos` / `tocados` | Los avisos | Reparto, barra de abajo |

### Cómo

```dart
// Sujeto: lib/data/repositories/pago_repository.dart
final _confirmados = StreamController<Pedido>.broadcast(sync: true);
Stream<Pedido> get pedidosConfirmados => _confirmados.stream;

// Observador: lib/ui/carrito/view_models/carrito_view_model.dart
_suscripcion = pagos?.pedidosConfirmados.listen((_) => vaciarCarrito());
...
void dispose() { _suscripcion?.cancel(); super.dispose(); }
```

- **`broadcast`** porque hay varios observadores del mismo dato.
- **`sync: true`** para que todos se enteren en el mismo momento del
  cambio. Ejemplo concreto: el `ApiClient` tiene que tener el token
  **antes** de que "Mi almacén" haga su primer pedido autenticado.
- **Sin paquetes externos**: solo `Stream` de Dart y `ChangeNotifier` de
  Flutter, como pide la materia.
- `PagoRepository` recuerda qué pedidos ya avisó: si dos consultas seguidas
  dicen "aprobado", avisa una sola vez.

Lo que cambió para quien usa la app: nada (mismo comportamiento), salvo que
ahora es más difícil romperlo. Lo que cambió en el código: ningún
ViewModel llama a otro; `main.dart` solo le pasa a cada uno los
repositorios que observa.

**Lo que siguió siendo callback, y por qué:** los avisos de **hijo a
padre** (`onAgregar` en `ProductoCard`, `alVerPedido`) y `armarPedido`, que
no es un aviso sino una **pregunta** ("dame el pedido armado").

### Observer en el backend

`backend/src/eventos.js` es un `EventEmitter`. Pagos y seguimiento solo
**anuncian** `pedidoAprobado`, `repartoEmpezado` y `pedidoEntregado`;
`avisos.js` **escucha** y manda los push. Los pagos no saben que existen las
notificaciones.

Diagramas: `docs/ARQUITECTURA.md` secciones 2 (flechas "observa") y 6.

## 3. Notificaciones push con FCM

### Qué avisa

| Cuándo | A quién | Al tocarlo |
|---|---|---|
| Entra un pedido (efectivo o pago aprobado) | Dueño y repartidores con sesión | Abre "Mi almacén" o "Repartir" |
| Sale el repartidor (su primera posición GPS) | Al cliente de ese pedido | Abre "Mi pedido" |
| Se entrega | Al cliente de ese pedido | Abre "Mi pedido" |

### Por qué así

- **El cliente no tiene cuenta** (decisión anterior, por los clientes
  mayores): su celular se anota **para ese pedido** cuando el pedido se
  confirma. No hace falta registrarse para recibir avisos.
- **Un aviso al salir, no uno por posición**: el GPS manda posiciones cada
  pocos segundos; avisar cada vez sería molesto.
- **"Llegó" reemplaza a "en camino"** en la barra (mismo id de
  notificación por pedido) en vez de apilarse.
- **Un push que falla nunca frena un pago ni una entrega**: se registra el
  error y sigue. Si Firebase dice que un celular ya no existe, se borra.
- **Funciona sin Firebase**: si falta la configuración, la app compila y
  anda igual, sin push. Nadie del grupo queda trabado.

### Cómo (capas)

| Capa | Pieza | Patrón |
|---|---|---|
| Servicio | `PushService` → `PushServiceFirebase` / `PushServiceSimulado` | Strategy + Adapter (`RemoteMessage` → `Aviso`) |
| Servicio | `NotificacionLocalServicePlugin` (`flutter_local_notifications`) | Con la app **abierta** Android no muestra el push solo: lo muestra la app |
| Servicio | `AvisosServiceHttp` | Le dice al backend qué avisos quiere este celular |
| Repositorio | `NotificacionesRepository` | Sujeto: `recibidos` y `tocados` |
| ViewModel | `AvisosViewModel` | Observa pedidos confirmados y sesión → anota o borra el celular |
| ViewModel | `NavegacionViewModel` / `RepartoViewModel` | Observan los avisos tocados / recibidos |
| Backend | `eventos.js` → `avisos.js` → `push.js` (`firebase-admin`) | Observer + Strategy (Firebase o consola) |
| Base | Tabla `dispositivos` con `CHECK` (pedido **o** rol) e índice único | — |

En la **demo sin backend**, el `SeguimientoServiceSimulado` hace de
servidor y "manda" los avisos por el push simulado: se ven en la barra del
celular igual que los reales.

**Permiso de notificaciones** (Android 13+): se pide al abrir la app. Si
se niega, "Mi pedido" muestra "Activá las notificaciones" con un botón,
explicando para qué sirve.

### Proyecto de Firebase

Creado el 07-11 con la cuenta de Ignacio: **`freshmarket-itu-2026`**, app
Android `com.freshmarket.freshmarket_app`. `android/app/google-services.json`
está en el repo (no es secreto: así cualquiera del grupo compila con push).
La **clave del servidor** (`backend/firebase-credenciales.json`) **no** se
sube: hay que pedírsela a Ignacio o generar otra desde la consola
(`docs/NOTIFICACIONES.md`, sección 4).

## 4. La app en un celular real

| Qué | Por qué |
|---|---|
| `flutter build apk --release` compila | Comprobado en la PC de Ignacio y probado en el emulador (sección 6). Hubo que actualizar el plugin de Android y Gradle (sección 5, punto 11) |
| Permiso `POST_NOTIFICATIONS` en el manifest | Android 13+ no muestra notificaciones sin él |
| Desugaring en `build.gradle.kts` | Lo exige `flutter_local_notifications` para Android viejos |
| Plugin de Google Services solo si existe `google-services.json` | Para que compile sin Firebase |
| `usesCleartextTraffic="true"` | Para hablar por `http` con el backend de la PC en la misma red (en producción va `https`) |
| Canal "Pedidos" como canal por defecto de Firebase | Los push con la app cerrada caen en el mismo canal que los locales |

Guía con las tres formas de instalarla (APK por WhatsApp, APK con backend
en la PC, cable USB), qué probar en el celular que el emulador no puede
(cámara, GPS, permisos, notificaciones, segundo plano, letra grande) y qué
faltaría para Play Store: `docs/CELULAR_REAL.md`.

## 5. Revisión del código: qué se encontró y qué se hizo

| # | Problema | Por qué importaba | Qué se hizo |
|---|---|---|---|
| 1 | Las pruebas del backend fallaban (`npm test`: 0/1) | Faltaba instalar `nodemailer` (dependencia nueva de la recuperación) | `npm install`: **34/34**. Es esperable al bajar cambios: el README ya dice `npm install` |
| 2 | 5 archivos sin formatear | Zoe no tenía el SDK donde escribió el cambio | `dart format lib test` |
| 3 | ViewModels encadenados con callbacks | Ver sección 2 | Observer entre capas |
| 4 | Al cerrar la sesión, apagar el GPS dependía de que `InicioScreen` se acordara de llamar a `reparto.detener()` | Si otra pantalla cerraba la sesión, el GPS seguía mandando la posición | El reparto **observa** la sesión y se apaga solo. `detener()` ahora además avisa a la vista |
| 5 | Dar de baja el celular de los avisos al salir necesitaba la sesión, que ya se había cerrado | La baja fallaba con 401 y el celular seguía recibiendo pedidos | `DELETE /dispositivos/:token` no pide sesión: tener el token alcanza (comentado en el código) |
| 6 | Si el token de Firebase no se conseguía (sin internet), quedaba guardado como "no hay" para siempre | El celular nunca se anotaba | Solo se guarda cuando se consigue; si no, se reintenta |
| 7 | `getToken()` de `firebase_messaging` 17 está marcado como viejo | `flutter analyze` lo marcaba | Se usa a propósito (es el token que documenta `firebase-admin`) y quedó comentado por qué |
| 8 | Marcar dos veces "entregado" | Mandaría dos avisos | Si ya estaba entregado, no se anuncia de nuevo (prueba incluida) |
| 9 | **Encontrado al probar en el emulador:** al tocar la notificación con la pantalla de pago abierta, la sección cambiaba "por debajo" y seguía viéndose el pago | La persona tocaba el aviso y no pasaba nada visible | `NavegacionViewModel.abiertasPorAviso` avisa y `main.dart` cierra las pantallas de encima (salvo un pago en curso, que tiene `PopScope`). Prueba de pantalla incluida y verificado de nuevo en el emulador |
| 10 | Con backend real pero sin Firebase, la app anotaba en la base un token falso de demo | Datos basura en la tabla `dispositivos` | Sin Firebase el token es `null` y no se anota nada |
| 11 | El APK no compilaba: `flutter_local_notifications` 23 exige compilar contra Android 37 y `androidx.core` 1.19 exige el plugin de Android 9.1 | Sin APK no hay prueba en celular | Android Gradle Plugin 9.0.1 → **9.1.0**, Gradle 9.1.0 → **9.3.1**, `compileSdk` ≥ 37 (el SDK 37 ya estaba instalado). `minSdk` no cambió: la app se sigue pudiendo instalar en los mismos celulares |
| 12 | **Encontrado con el push real:** con la app cerrada, al tocar "Tu pedido está en camino" se abría "Mi pedido" **vacío**: el pedido que se seguía vivía solo en memoria | El aviso decía "Seguilo en el mapa" y no había nada que seguir. Y cualquier cliente que cerrara la app perdía el seguimiento | El pedido en curso se guarda en el celular (`PedidoLocalService` con `shared_preferences`, como el carrito). `SeguimientoViewModel.restaurar()` lo retoma al abrir la app; "Hacer otro pedido" lo borra. 6 pruebas nuevas y verificado de nuevo con el push real |

**Revisado sin problemas:** recuperación de contraseña (huella HMAC,
`timingSafeEqual`, vencimiento, intentos, un solo uso, transacción),
contraseñas con scrypt y sal, `ElegirUbicacionViewModel` (descarta
respuestas viejas), `CampoClave`, liberación de todos los
`TextEditingController` y `MapController` en `dispose()`, `mounted`
después de cada `await` en las pantallas.

**Queda anotado (no se cambió):** las sesiones del dueño y del repartidor
son por **rol** y duran 12 h; cambiar la contraseña no cierra las sesiones
ya abiertas. Para eso habría que guardar las sesiones en la base. Prioridad
baja para el alcance del TP.

## 6. Pruebas: cómo se comprobó

| Conjunto | Antes | Ahora | Resultado (07-11, PC de Ignacio) |
|---|---|---|---|
| App (`flutter test`) | 90 | **128** | **128/128 pasan** |
| Backend (`cd backend && npm test`) | 34 | **44** | **44/44 pasan** |
| `flutter analyze` | — | — | **Sin problemas** |
| `dart format lib test` | 5 archivos sin formato | — | Todo formateado |
| `flutter build apk --release` | No compilaba (punto 11) | — | **Compila: `app-release.apk`, 52 MB** |
| Prueba a mano en el emulador Pixel 7 (Android 16) con el APK de release | — | — | Ver abajo |

Pruebas nuevas:

- `test/observer_test.dart` (9): un `notifyListeners()` le llega a todos los
  observadores y no a los dados de baja; un producto cargado con foto
  aparece en "Comprar" y "Mi almacén"; un ViewModel descartado deja de
  observar; pago aprobado → carrito vacío y "Mi pedido" siguiendo; pago
  rechazado → nadie se entera; entra el dueño → "Mi almacén" abierto y
  cargado; entra el repartidor → "Repartir"; al salir se apaga el GPS.
- `test/notificaciones_test.dart` (21): el modelo `Aviso` (datos de
  Firebase, tipo desconocido, ida y vuelta como texto, texto roto, mismo id
  por pedido); el repositorio (canal y permiso una vez, push con la app
  abierta se muestra, tocar push o local llega igual, token pedido una vez,
  sin token reintenta, permiso negado); `AvisosViewModel` (se anota al
  confirmar, al entrar y al salir, sin conexión la compra sigue, cartel de
  permiso, plugin roto no rompe la app); quién observa (tocar abre la
  sección correcta según la sesión, el repartidor ve el pedido nuevo, un
  cliente no recarga el reparto); el servidor simulado manda 2 avisos.
- `backend/test/avisos.test.js` (10): anotarse (404, token inválido, sin
  duplicar, sesión obligatoria para el almacén); quién recibe qué (efectivo
  avisa al almacén y no al cliente; con tarjeta recién al aprobarse; "en
  camino" una sola vez aunque lleguen 3 posiciones; "llegó" una sola vez
  aunque se marque dos veces; al cerrar sesión deja de recibir); si
  Firebase falla (token vencido se borra; un error no rompe el pedido).
- `test/widget_test.dart` (+2): un aviso con la app abierta se muestra en la
  barra; tocar el aviso desde el pago cierra el pago y abre "Mi pedido".
- `test/pedido_guardado_test.dart` (6): el pedido va al disco y vuelve
  igual; al cerrar y abrir la app se sigue el mismo pedido y se vuelve a
  escuchar al repartidor; "Hacer otro pedido" lo borra; no pisa un pedido
  en curso; lo guardado roto se descarta; sin disco no hace nada.
- Se adaptaron las pruebas que usaban los callbacks viejos (`almacen`,
  `escaner`, `pago`, `sesion`, `carrito_guardado`) para que verifiquen lo
  mismo observando al repositorio.

**Prueba a mano con el APK de release en el emulador** (modo demo):

1. Al abrir, Android pide el permiso de notificaciones → se negó.
2. Pedido en efectivo → "¡Listo! Tu pedido está confirmado. Pedido #1001" →
   "Mi pedido" muestra el cartel **"Activá las notificaciones"** y la bici en
   el mapa.
3. "Activar" → Android vuelve a preguntar → se permitió → el cartel
   desaparece.
4. Otro pedido y la app a segundo plano (botón de inicio) → a los ~6 s llega
   **"Tu pedido está en camino · Tobías ya salió en bici"** en la barra, en el
   canal "Pedidos" con prioridad alta.
5. Tocar la notificación → se abre la app en **"Mi pedido"** (acá apareció el
   problema 9, que se corrigió y se volvió a probar).

**Prueba con el push real de Firebase** (backend en la PC con la clave de
Firebase, app compilada con `URL_BACKEND=http://10.0.2.2:3000`):

1. Al abrir, la app inicia Firebase (`FirebaseApp initialization successful`)
   y pide el token.
2. Ingreso como dueño → la barra pasa sola a "Mi almacén" y el backend
   guarda el token (142 caracteres) con rol `dueno` en `dispositivos`.
3. Con la app en segundo plano, otro cliente pide en efectivo → llega
   **"Nuevo pedido #1001 · $7.600 · Belgrano 55"**. Al tocarlo, abre "Mi
   almacén".
4. "Salir" → el celular se da de baja (la tabla queda vacía).
5. Como cliente: pedido en efectivo → el celular se anota para ese pedido.
6. Con la **app cerrada** (sin proceso), el repartidor manda su primera
   posición → llega **"Tu pedido #1003 está en camino"**. Al tocarlo, la app
   arranca desde cero y abre "Mi pedido" **con el pedido y la bici en el
   mapa** (acá apareció el problema 12, que se corrigió y se volvió a probar).
7. El repartidor marca entregado → **"Tu pedido #1003 llegó"** reemplaza al
   aviso anterior.

Sin probar todavía: un celular físico.

Comandos para repetirlo:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
cd backend && npm install && npm test
```

## 7. Archivos nuevos y cambiados

**Nuevos (app):** `domain/models/aviso.dart`,
`data/services/push_service.dart`, `data/services/notificacion_local_service.dart`,
`data/services/avisos_service.dart`, `data/services/pedido_local_service.dart`,
`data/repositories/notificaciones_repository.dart`,
`ui/avisos/view_models/avisos_view_model.dart`.

**Nuevos (backend):** `src/eventos.js`, `src/avisos.js`, `src/push.js`,
`test/avisos.test.js`; tabla `dispositivos` en `sql/schema.sql`; rutas
`POST /pedidos/:id/avisos`, `POST /dispositivos`, `DELETE /dispositivos/:token`.

**Cambiados:** los repositorios de catálogo, sesión y pago (publican sus
cambios); los ViewModels de catálogo, almacén, escáner, carrito, pago,
seguimiento, sesión, navegación y reparto (observan); `main.dart` y
`dependencias.dart` (arman las suscripciones, Firebase y el cierre de
pantallas al tocar un aviso); `IngresarScreen`
e `InicioScreen` (sin callbacks entre ViewModels); `SeguimientoScreen`
(cartel del permiso); configuración de Android (permiso, desugaring,
Google Services, AGP 9.1, Gradle 9.3.1, `compileSdk` 37); `pagos.js`, `seguimiento.js`,
`sesiones.js`, `app.js`, `server.js` en el backend.

**Documentación:** este informe, `docs/GUIA_PATRONES.md`,
`docs/NOTIFICACIONES.md`, `docs/CELULAR_REAL.md`; actualizados
`README.md`, `docs/ARQUITECTURA.md` (diagramas de clases, base de datos y
secciones 6 y 7), `INFORME_TEORIA_Y_PATRONES.md` e `INFORME_MEJORAS.md`.

> `EXPLICACION_CODIGO.md` describe la **versión 1** (pantallas `HomeScreen`,
> `MetodoPagoScreen`): sirve como historia, pero para el código actual usar
> `docs/GUIA_PATRONES.md` y `docs/ARQUITECTURA.md`.

## 8. Qué falta

| Pendiente | Por qué | Quién / prioridad |
|---|---|---|
| Pasar la clave del servidor de Firebase a quien levante el backend en la EGI | No está en el repo (es secreta) | **Alta, antes de la EGI** |
| Probar el APK en un celular de cada uno | Criterio F2 de la grilla (`docs/CELULAR_REAL.md`, tabla "Qué probar") | **Alta** |
| Correo real para la recuperación (`SMTP_URL`) | Sin eso el código aparece en la consola del servidor | Alta |
| GPS del repartidor con la pantalla apagada | Servicio en primer plano y permisos que Google Play revisa a mano | Media |
| Cerrar las sesiones abiertas al cambiar la contraseña | Sección 5 | Baja |
| Firma propia y publicación en Play Store | `docs/CELULAR_REAL.md`, "Publicación" | Baja |
