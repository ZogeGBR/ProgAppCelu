# Informe: teoría de la materia y patrones en FreshMarket

Programación de Aplicaciones para Celulares · ITU

García Badiola, Zoe — Lopez, Matias — Morichetti Ramal, Ignacio

## 1. Qué se pidió y qué se hizo

| Pedido | Resultado | Dónde |
|---|---|---|
| Ver la contraseña al escribirla | Botón del **ojo** en todos los campos de contraseña (ingreso y recuperación). Se reutiliza un solo widget, `CampoClave` | `lib/ui/core/widgets/campo_clave.dart` |
| Recuperar la contraseña | "¿Olvidaste tu contraseña?" → email → **código de 6 números por correo** → contraseña nueva (dos veces, con el ojo). El email ya escrito pasa solo a la recuperación | `lib/ui/sesion/`, `backend/src/recuperacion.js`, `backend/src/correo.js` |
| Tocar el mapa y que aparezca la dirección | Al tocar el mapa se busca la **calle y número** de ese punto (OpenStreetMap/Nominatim, o Google si hay clave) y se escribe sola en el cuadro de dirección del pedido. También está el botón **"Usar mi ubicación"** (GPS) | `lib/ui/pago/`, `lib/data/repositories/ubicacion_entrega_repository.dart`, `backend/src/geo.js` |
| Que se vean las clases en sus capas | Diagramas de capas, de clases, de modelos, de secuencia y de la base de datos | `docs/ARQUITECTURA.md`, `docs/diagramas/` |
| Ciclo MVC sin romper el encapsulamiento | MVVM (la versión de MVC que usa la materia) verificado regla por regla. Se corrigieron dos fallas encontradas | sección 3 |
| SQL armado | Esquema con claves, índices y restricciones, datos iniciales y script para crear la base | `backend/sql/schema.sql`, `backend/sql/seed.sql`, `npm run bd:crear` |
| Usar toda la teoría y justificar lo que no se usa | Tabla de la sección 2 | — |

**Cuentas del almacén.** Antes, el dueño y el repartidor entraban con una
clave compartida escrita en el servidor, así que no había nada que
"recuperar". Ahora cada uno tiene su **cuenta con email y contraseña**
(tabla `usuarios`). La contraseña se guarda como huella **scrypt con sal**,
nunca en texto plano. Los clientes siguen comprando **sin cuenta**, a
propósito: muchos son personas mayores y un registro sería una traba.

## 2. Teoría y patrones: dónde se usó cada uno y por qué no los otros

| Concepto | ¿Se usó? | Dónde | Por qué / por qué no |
|---|---|---|---|
| **Observer** | Sí, en dos niveles | **Vista ← ViewModel:** todos los ViewModels (`ChangeNotifier` + `notifyListeners()`) y las vistas con `ListenableBuilder`. **ViewModel ← Repositorio** (desde el 07-11): los repositorios publican sus cambios en un `Stream` (`CatalogoRepository.cambios`, `SesionRepository.cambios`, `PagoRepository.pedidosConfirmados`, `NotificacionesRepository.recibidos/tocados`) y los ViewModels se suscriben. **Backend:** `eventos.js` (`EventEmitter`) avisa "pedido aprobado / en camino / entregado" y `avisos.js` escucha | Es la base de MVVM: la vista se entera sola de los cambios y el ViewModel no conoce ningún widget. En la capa de datos reemplaza los callbacks entre ViewModels: ninguno llama a otro. Ver `INFORME_CAMBIOS_07-11.md`, sección 2 |
| **MVVM / MVC** | Sí | `ui/*/widgets` (Vista), `ui/*/view_models` (ViewModel, que hace de Controlador), `domain` + `data` (Modelo) | Ver `docs/ARQUITECTURA.md`, sección 4 |
| **Repository** | Sí | `lib/data/repositories/` (9 repositorios, uno nuevo: `NotificacionesRepository`) | Única fuente de verdad: convierte JSON en modelos, guarda caché y decide reintentos y esperas |
| **Inyección de dependencias** | Sí | Constructores de repositorios y ViewModels; `config/dependencias.dart` arma todo | Permite cambiar real por simulado tocando un solo archivo y probar cada pieza con fakes |
| **Strategy** | Sí | Cada interfaz de servicio con su versión real y simulada (14 interfaces desde el 07-11); `backend/src/correo.js` (SMTP o consola); `backend/src/geo.js` (Google, Nominatim o simulado) | Se elige el comportamiento sin `if` repartidos por el código |
| **Factory** | Sí | `fromJson` en los modelos; `Dependencias.desdeConfiguracion()` y `.simuladas()`; `crearCorreo()` y `crearGeocodificador()` en el backend | Un solo lugar sabe cómo construir cada cosa |
| **Adapter** | Sí | `backend/src/geo.js` convierte las respuestas de Google y de Nominatim (distintas) en `{ direccion }`; los servicios HTTP adaptan el JSON del backend | La app no se entera de qué proveedor de mapas se usa |
| **Singleton** | Sí, donde corresponde | Backend: una sola conexión a la base (`bd.js`, `abrirBd`/`obtenerBd`). App: `SharedPreferences.getInstance()` | En la app **no** se escribió ninguna clase con `static instancia`: un Singleton clásico es estado global que no se puede reemplazar en las pruebas. `Dependencias` crea **una sola instancia** de cada repositorio y un solo `ApiClient` y los pasa por constructor: misma garantía y se puede probar |
| **Callbacks** | Sí, solo de vista a padre | `armarPedido`, `crearRecuperacion`, `crearElegirUbicacion`, `alVerPedido`, `onAgregar` | Un widget hijo avisa al padre. Los callbacks **entre ViewModels** (`alAprobar`, `alIngresar`, `alGuardar`, `alCambiarCatalogo`, `alCambiarToken`) se reemplazaron por Observer el 07-11 |
| **Encapsulamiento e inmutabilidad** | Sí | Estado privado con `_`, getters públicos, `List.unmodifiable`, modelos con `final` y `copiarCon`. El token del `ApiClient` pasó a ser privado (`usarToken`) | Nadie puede cambiar un dato sin pasar por el comando que avisa |
| **Future / async / await** | Sí | Toda llamada a red, disco, GPS y cámara | — |
| **Timeout** | Sí | `ApiClient` (10 s), IA (30 s), GPS (15 s), mapa en el backend (8 s), espera del pago (5 min) | Ninguna pantalla queda cargando para siempre |
| **`context.mounted` después de un await** | Sí | `IngresarScreen`, `_DireccionState`, pantallas de pago | La pantalla puede haberse cerrado mientras se esperaba |
| **Respuestas viejas que llegan tarde** | Sí | `ElegirUbicacionViewModel.marcar()` numera cada consulta y descarta las anteriores | Si la persona toca el mapa dos veces rápido, vale el último toque aunque la primera respuesta llegue después |
| **Isolate** | Sí | `EtiquetadoServiceHttp`: `Isolate.run(() => base64Encode(foto))` | Pasar una foto de ~1 MB a texto es trabajo de CPU y trababa la animación de "Mirando la foto..." |
| Isolate para el catálogo | No | — | Son decenas de productos: copiar los datos a otro isolate cuesta más que leerlos en el principal |
| **Persistencia local** (`shared_preferences`) | Sí | Carrito guardado en el celular (`CarritoLocalServicePreferencias` + `CarritoRepository`) y, desde el 07-11, el **pedido en curso** (`PedidoLocalServicePreferencias` + `SeguimientoRepository`) | Si la persona sale de la app o el sistema la cierra, al volver el carrito y el seguimiento siguen ahí (también al abrirla tocando una notificación) |
| SQLite en el celular (`sqflite`) | No | — | La app no necesita consultas locales: el historial de pedidos vive en la base del servidor (SQL). Para un carrito alcanza con clave y valor |
| Almacenamiento seguro (`flutter_secure_storage`) | No | — | Decisión de seguridad: la sesión del dueño **no** se guarda en el celular, porque queda sobre el mostrador del almacén. Si se agrega "recordarme", el token iría ahí |
| **SQL en el servidor** | Sí | `backend/sql/schema.sql`: 6 tablas con `PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY ... ON DELETE CASCADE`, `CHECK` e índices; transacciones en `enTransaccion()` | Los datos se validan también en la base, no solo en el código |
| **Eventos del sistema** (ciclo de vida) | Sí | `AppLifecycleListener` en `main.dart` (`onHide` / `onPause` → guardar carrito) | Es el último momento seguro: en segundo plano el sistema puede cerrar la app sin avisar |
| Otros eventos del sistema | Sí | `PopScope` (botón atrás bloqueado mientras se paga); tema y tamaño de letra del sistema respetados por `MediaQuery` | — |
| Consultar el pago al volver (`onResume`) | No hizo falta | — | La espera del pago ya consulta cada 3 s mientras la pantalla está abierta: al volver de Mercado Pago, la próxima consulta llega sola |
| Detectar conexión (`connectivity_plus`) | No | — | Saber que hay Wi-Fi no garantiza internet. La app decide "sin conexión" por el resultado real de cada llamada (timeout y reintento), que es más confiable |
| **Segundo plano** (GPS del repartidor con la pantalla apagada) | No, pendiente | — | Requiere un servicio en primer plano con notificación fija y los permisos `ACCESS_BACKGROUND_LOCATION` y `FOREGROUND_SERVICE_LOCATION`, que Google Play revisa a mano. Hoy el repartidor comparte el GPS con la app abierta |
| Tareas diferidas (`workmanager`) | No | — | No hay nada que sincronizar después: todo se manda en el momento |
| **Notificaciones push (FCM)** | Sí (07-11) | App: `PushServiceFirebase` (`firebase_messaging`) + `NotificacionLocalServicePlugin` (`flutter_local_notifications`) + `NotificacionesRepository` + `AvisosViewModel`. Backend: `push.js` (`firebase-admin`), `avisos.js`, tabla `dispositivos` | El cliente se entera cuando su pedido sale y cuando llega, aunque tenga la app cerrada; el almacén, de cada pedido nuevo. Ver `docs/NOTIFICACIONES.md` |
| Notificaciones locales | Sí (07-11) | `NotificacionLocalServicePlugin` | Con la app abierta Android no muestra el push solo: la app lo muestra. En la demo sin backend, todos los avisos son locales |
| Permisos en tiempo de ejecución | Sí | Ubicación (`geolocator`), cámara, **notificaciones** (`POST_NOTIFICATIONS`, Android 13+) | Se piden cuando hacen falta y, si se niegan, la app sigue y explica para qué sirven ("Activá las notificaciones" en "Mi pedido") |
| Canales de plataforma (`MethodChannel` / `EventChannel`) | No directo | Los usan por dentro `geolocator`, `image_picker`, `url_launcher` y `shared_preferences` | No hay ninguna función nativa que no tenga ya un paquete oficial |
| **Código limpio** | Sí | Nombres en español consistentes, una función una cosa, constantes con nombre, enums en vez de números, `switch` de expresión, comentarios que explican el porqué | `analysis_options.yaml` suma `prefer_single_quotes`, `unawaited_futures` y `use_build_context_synchronously` |
| **Refactoring con pruebas** | Sí | Cada cambio se hizo con las pruebas existentes como red de seguridad y se sumaron pruebas nuevas | — |

## 3. Encapsulamiento y capas: qué se revisó

| Regla | Estado |
|---|---|
| Ningún ViewModel llama a otro ViewModel | **Se corrigió (07-11)**: antes se encadenaban con callbacks (`alAprobar` vaciaba el carrito y arrancaba el seguimiento). Ahora cada uno observa al repositorio que le interesa |
| Ninguna vista habla con la red | Cumple (`grep "ApiClient\|http\." lib/ui` vacío) |
| Ningún ViewModel importa `material.dart` | Cumple |
| Ningún ViewModel importa la capa de servicios | **Se corrigió**: `RepartoViewModel` importaba `ubicacion_service.dart` para usar `PermisoUbicacion`; ese enum pasó al dominio (`domain/models/permiso_ubicacion.dart`) |
| Ningún campo público se puede modificar desde afuera | **Se corrigió**: `ApiClient.token` era público y cualquiera podía cambiarlo. Ahora es privado y solo se cambia con `usarToken()`. Desde el 07-11 lo llama un observador de `SesionRepository.cambios` (en `config/dependencias.dart`) |
| Las listas que salen de un ViewModel no se pueden modificar | Cumple (`List.unmodifiable`) |
| Estado de la vista vs. estado de la app | Mostrar u ocultar la contraseña es estado **de la vista** (no cambia ningún dato), por eso vive en el `State` de `CampoClave` y no en un ViewModel |

## 4. Seguridad de las cuentas

- Contraseñas con **scrypt + sal** por usuario; nunca en texto plano (hay
  una prueba que lo verifica).
- Ingreso: el mensaje es el mismo si el email no existe o si la contraseña
  está mal, y tarda lo mismo (se compara contra una huella falsa).
- Recuperación: la respuesta es igual exista o no el email. El código de 6
  números se guarda como HMAC, **vence a los 15 minutos**, admite **5
  intentos** y sirve **una sola vez**. Pedir otro anula el anterior.
- Límite de intentos por minuto en el ingreso y en la recuperación.
- La contraseña nueva tiene que tener al menos 8 caracteres.

## 5. Pruebas

| Conjunto | Pruebas | Resultado |
|---|---|---|
| Backend (`cd backend && npm test`) | **34**: cuentas, huella de la contraseña, límite de intentos, recuperación (código correcto, equivocado, vencido por intentos, un solo uso, email inexistente), dirección desde el mapa con caché, catálogo, pagos, webhook, reparto | **34/34 pasan** |
| App (`flutter test`) | **90** (antes 67): +7 recuperación, +8 mapa → dirección (incluye toques rápidos, caché, sin calle, GPS sin permiso), +5 carrito guardado, +1 sesión con email, +2 pantallas (el ojo y la recuperación completa de punta a punta) | **90/90 pasan** (corridas el 07-11 en la PC de Ignacio; `flutter analyze` sin problemas). Con los cambios del 07-11 son más: ver `INFORME_CAMBIOS_07-11.md` |

Comandos para validar antes de entregar:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
cd backend && npm install && npm test
```

## 6. Qué faltaría

| Pendiente | Por qué | Prioridad |
|---|---|---|
| ~~Correr `flutter analyze` y `flutter test` con estos cambios~~ | Hecho el 07-11: todo pasa | — |
| Configurar un correo real (`SMTP_URL`) | Sin eso, el código de recuperación aparece en la consola del servidor | Alta |
| GPS del repartidor en segundo plano | Ver sección 2 (servicio en primer plano y permisos) | Alta |
| ~~Notificaciones push~~ | Hecho el 07-11 (falta cargar el proyecto de Firebase: `docs/NOTIFICACIONES.md`) | — |
| Hosting con https y base de datos administrada | Para producción y para el webhook de Mercado Pago | Media |
| Proveedor de mapas pago si crece el uso | Nominatim permite 1 consulta por segundo; la caché en la base lo alivia | Baja |
| Pantalla para que el dueño cree cuentas de repartidores | Hoy se crean desde el `.env` del servidor | Baja |
