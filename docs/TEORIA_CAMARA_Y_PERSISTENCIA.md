# FreshMarket frente a los apuntes de Cámara, Persistencia local y Datos en la nube

Comparación del proyecto con los tres apuntes de la materia (25/11) y lo
que se corrigió para cumplirlos.

## Cámara

| Lo que pide el apunte | En FreshMarket |
|---|---|
| Capacidad y política: si no hay cámara, deshabilitar en vez de fallar | `Politicas.puedeSacarFotos` y `permiteCargaConFoto`; el botón queda en `null` |
| `image_picker` con cámara y galería | "Sacar foto" y "Elegir una foto guardada" |
| Achicar la foto al elegirla | `maxWidth: 1024`, `imageQuality: 80` |
| Cancelar no es un error | `null` → no pasa nada, sin mensaje |
| Error real traducido a uno propio con mensaje | **Nuevo:** `CamaraServiceImagePicker` traduce `PlatformException` a `ErrorDeFoto` (en el dominio) con un mensaje por código ("No tenemos permiso para usar la cámara…") y la pantalla lo muestra |
| No abrir la cámara dos veces | **Nuevo:** `EscanerViewModel.estaOcupado`; los botones se deshabilitan |
| `retrieveLostData()` al iniciar | **Nuevo:** `CamaraService.recuperarPerdida()`, llamado al abrir la app (`main.dart`); si Android cerró la app con la cámara abierta, la foto vuelve y se analiza |
| Claves de `Info.plist` que explican el uso | `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` |
| Interfaz inyectada; la foto como bytes | `CamaraService` con su falsa (`CamaraFalsa`); `Uint8List` |
| Copiar la foto a documentos y guardar la ruta | No aplica: la foto se usa para leer el envase y se descarta (el catálogo usa emojis) |

## Persistencia local

| Lo que pide el apunte | En FreshMarket |
|---|---|
| `SharedPreferencesAsync` | Sí |
| Clase `Preferencias` con las claves como constantes | Sí, con `todasLasClaves` y `olvidarTodo()` (borra solo las de la app) |
| La instancia se recibe por constructor | **Nuevo:** `Preferencias([SharedPreferencesAsync? almacen])`; las pruebas usan `InMemorySharedPreferencesAsync` |
| Una lista de objetos (el carrito) no va como JSON en preferencias | **Corregido:** el carrito pasó a la tabla `carrito` de SQLite, una fila por producto (`CarritoDao`). En la Web, donde no hay SQLite, sigue en preferencias por política |
| Un objeto chico sí puede ir como JSON | El pedido en curso (uno solo) queda en preferencias |
| Secretos nunca en preferencias | El token de sesión vive solo en memoria |
| SQLite: DAO, `toMap`/`fromMap`, `?` y `whereArgs`, `version` y `onUpgrade` | `BaseLocal` (versión 3) con `HistorialDao` y `CarritoDao`; migraciones 1→2 (dirección) y 2→3 (tabla carrito) |
| SQLite no tiene bool | `disponible` va como 1 o 0 |
| `(valor as num).toDouble()` | En `ItemCarrito.fromMap` y en los modelos |
| Transacción: todo o nada | **Nuevo:** guardar el carrito borra e inserta dentro de una transacción |
| Ruta con `join` | **Nuevo:** `p.join(getDatabasesPath(), 'freshmarket.db')` |
| Fábrica inyectada y pruebas en memoria | `databaseFactoryFfi` con `inMemoryDatabasePath` |
| Prueba de "cerrar y volver a abrir" | `persistencia_local_test.dart`, `carrito_guardado_test.dart`, `pedido_guardado_test.dart` |

## Datos en la nube

FreshMarket no usa Firestore: usa un **servidor propio** (Node.js + SQLite).
Las ideas del apunte están, con otras herramientas:

| Idea del apunte | En FreshMarket |
|---|---|
| Datos compartidos entre dispositivos | Productos, pedidos y usuarios en el servidor |
| Cambiar dónde viven los datos toca una sola capa | El repositorio; `dependencias.dart` elige demo o real |
| Leer con desconfianza (`as num`, valores por defecto) | `fromJson` de los modelos |
| Traducir errores en el repositorio | `ApiException` → errores del dominio (`SinLugarParaPedidos`) |
| Reglas de seguridad | Roles en el servidor (`exigirRol`) y claves solo en el servidor |
| Escrituras juntas (`WriteBatch`) | `enTransaccion` (BEGIN/COMMIT) |
| Pruebas sin internet (`fake_cloud_firestore`) | Servicios falsos y `MockClient` |
| Datos en vivo (`snapshots()`) | Parcial: el seguimiento consulta cada pocos segundos y los push avisan los cambios |
| Copia local con cola sin conexión | No: sin internet no se puede pedir (el carrito sí queda guardado) |

**Por qué un servidor propio y no Firestore:** las claves de Mercado Pago y
de Gemini no pueden estar en la app, y los precios y el cupo de 100 pedidos
se controlan en el servidor. Con Firestore la app habla directo con la base
y esa lógica quedaría en el celular, donde se puede modificar.
