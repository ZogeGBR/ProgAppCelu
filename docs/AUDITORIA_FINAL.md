# Auditoría final de FreshMarket (15/11, actualizada el 25/11)

> **Actualización del 25/11.** Después de la presentación se compararon el
> código y los apuntes de la materia (cámara, persistencia y datos en la
> nube) y se corrigió lo que faltaba: el carrito pasó a **SQLite** (tabla
> `carrito`, `BaseLocal` versión 3 con migraciones), `Preferencias` usa
> `SharedPreferencesAsync` inyectado, la cámara traduce sus errores a
> `ErrorDeFoto` y recupera la foto perdida, y la demo usa datos reales
> (Nominatim, OSRM y ML Kit). Las pruebas pasaron a **200** (verificadas en
> la PC: `flutter analyze` sin avisos y `All tests passed!`). Detalle en
> [`TEORIA_CAMARA_Y_PERSISTENCIA.md`](TEORIA_CAMARA_Y_PERSISTENCIA.md).

Revisión del código de la rama `main` antes de la presentación del 19/11,
contra tres cosas: el concepto de **MVC/MVVM**, la **rúbrica** de la
profesora (18 criterios) y lo **pedido al inicio** por Don Ceferino (más
las correcciones del 07/11). Cada veredicto tiene su evidencia: un archivo,
una prueba o un comando.

## Resumen

| Tema | Resultado |
|---|---|
| Rama por defecto del repositorio | `main` (confirmado en GitHub) |
| Reglas de capas MVC/MVVM | **5 de 5 se cumplen, sin excepciones** |
| Encapsulamiento | 3 huecos chicos, **corregidos** (ver abajo) |
| Rúbrica | 17 de 18 con evidencia completa; **F2 espera las capturas del celular real** |
| Pedidos de Don Ceferino | 6 de 6 resueltos; el de 5.000 pedidos, justificado y dimensionado para 100 por día y 100 por minuto |
| Correcciones del 07/11 | 6 de 6 en el código |
| Pruebas | App: **200/200** en 24 archivos (25/11); backend: **52/52** |
| Riesgos de celular real encontrados | 2, **corregidos** (ícono de notificaciones e iOS) |

## 1. MVC / MVVM

La app usa **MVVM**, la versión de MVC que recomienda Flutter: la **Vista**
(widgets) muestra y reenvía gestos; el **ViewModel** (`ChangeNotifier`)
tiene el estado y la lógica de presentación; el **Modelo** son los modelos
de dominio más los repositorios y servicios de la capa de datos. El ciclo
no se rompe si cada capa solo conoce a la de abajo. Se comprobó buscando
los `import` de cada capa:

| Regla | Cómo se comprobó | Resultado |
|---|---|---|
| Ningún ViewModel importa `material`, `widgets` ni `cupertino` | `grep` en `lib/ui/*/view_models/` | 0 casos |
| Ningún ViewModel usa un servicio (solo repositorios) | `grep data/services` en los ViewModels | 0 casos |
| Ninguna vista usa repositorios, servicios ni HTTP | `grep data/` y `http` en `lib/ui/*/widgets` | 0 casos |
| Ningún ViewModel importa a otro ViewModel | `grep view_models/` en los ViewModels | 0 casos |
| El dominio no depende de Flutter ni de la capa de datos | `grep import` en `lib/domain` | solo `foundation.dart` (para `TargetPlatform`) |

Además:

- **Ningún ViewModel tiene setters públicos ni campos públicos que se
  puedan cambiar desde afuera**: todo el estado es privado (`_estado`) y se
  lee por getters.
- **`notifyListeners` solo se llama dentro de los ViewModels.**
- **Los modelos de dominio son inmutables** (todos sus campos son `final`).
- **Las vistas no escriben estado del ViewModel**: solo llaman métodos
  (`viewModel.cambiarPrecio(...)`).
- **Coordinación entre ViewModels sin acoplarlos.** "Volver a pedir" lo
  arma la vista de inicio (`catalogo.conPreciosDeHoy` → `carrito.agregarItems`).
  El pago recibe `armarPedido` como función, no al `CarritoViewModel`
  entero. El resto se comunica observando repositorios (patrón Observer).
- **Una sola raíz de composición**: `lib/config/dependencias.dart` decide
  qué implementación usar (real o simulada) y `main.dart` crea los
  ViewModels una vez y los descarta en `dispose`.

### Huecos de encapsulamiento corregidos

`AlmacenViewModel.productos`, `RepartoViewModel.pedidos` y
`HistorialViewModel.pedidos` devolvían su lista interna. Una vista podía
hacer `.add()` o `.clear()` y cambiar el estado sin pasar por el ViewModel
y sin que nadie se enterara. Ahora devuelven `List.unmodifiable(...)`, como
ya hacía `CarritoViewModel.items`. Nueva prueba: "la lista es de solo
lectura: la vista no puede cambiar el estado" (`almacen_view_model_test.dart`).

## 2. Rúbrica (18 criterios)

| Criterio | Estado | Evidencia comprobada en el código |
|---|---|---|
| **A1** Alcance | Cumple | Tabla "De la entrevista al código" (README); `backend/src/cupo.js` (100 por día y por minuto) y `backend/scripts/carga.mjs` |
| **B1** Widgets | Cumple | `VistaMensaje`, `CampoClave`, `SelectorCantidad`, `ProductoCard`, `AvisoSinInternet`, `HistorialDePedidos`; `tema.dart` |
| **B2** Estado y ciclo de vida | Cumple | 8 `StatefulWidget` con `initState`/`dispose`; `didUpdateWidget` en `mapa_repartidor.dart` |
| **B3** Navegación y gestos | Cumple | `rutas.dart` + `onGenerateRoute`; mantener apretado, deslizar con "Deshacer", tirar para recargar; pruebas en `presentacion_final_test.dart` |
| **B4** Multiplataforma | Cumple | Íconos y splash **generados y subidos** (`e29a768`), permisos con motivo, grilla desde 840 de ancho, versión `1.1.0+2`; reglas de R8 (`proguard-rules.pro`) para el release con ML Kit; sección iOS en `PUBLICACION.md` (iOS necesita una Mac; ML Kit pide iOS 15.0) |
| **C1** Capas | Cumple | Sección 1 de este informe; `docs/diagramas/capas.png`, `clases.png`, `base_celular.png` y `secuencia_camara.png` (regenerados el 25/11) |
| **C2** Código limpio | Cumple | `flutter analyze` sin avisos con `unawaited_futures` y `use_build_context_synchronously` |
| **C3** Refactoring | Cumple | `caracterizacion_test.dart`; refactorings nombrados en `INFORME_MEJORAS.md` |
| **C4** Pruebas | Cumple | 24 archivos de prueba (**200** pruebas, SQLite y preferencias en memoria) + 52 del backend; capturas en `docs/evidencias/` |
| **D1** Políticas | Cumple | `politicas.dart` con los tres chequeos; `politicas_test.dart`, `funciones.test.js` |
| **D2** Future | Cumple | `timeout` en `funciones_repository.dart`, `ruta_service.dart` y `geocodificacion_service.dart`; `Future.wait` en `main.dart` (incluye recuperar la foto perdida); `context.mounted` en `ingresar_screen.dart` |
| **D3** Streams e Isolates | Cumple | `Stream.periodic` + `asyncMap` (`seguimiento_service.dart`), `distinct()` (`conectividad_repository.dart`), `Isolate.run` (`etiquetado_service.dart`) |
| **E1** Notificaciones | Cumple | 4 casos de FCM en `push_service.dart`; 21 pruebas en `notificaciones_test.dart` |
| **E2** Segundo plano | Cumple | `zonedSchedule` + receptores de reinicio en el manifest; `segundo_plano_y_eventos_test.dart` |
| **E3** Eventos del sistema | Cumple | `AppLifecycleListener` en `main.dart`; `connectivity_plus` con aviso; prueba "sin internet aparece el aviso" |
| **F1** Persistencia, APIs y cámara | Cumple | `base_local.dart` (una base, versión 3, migraciones) con `historial_dao.dart` y `CarritoDao` (SQLite, `?`, transacción); `preferencias.dart` (`SharedPreferencesAsync` inyectado); `camara_service.dart` (`ErrorDeFoto`, `retrieveLostData`); `backend/sql/schema.sql` (7 tablas); Mercado Pago, Gemini, Nominatim, OSRM y ML Kit |
| **F2** Celular real y publicación | **Falta la evidencia** | APK release compilado (55,1 MB) y firma configurada. Faltan las capturas en el celular: `docs/GUIA_APK_DESDE_CERO.md`, paso 11 |
| **G1** Demo y defensa | Cumple | `docs/DEMO_Y_DEFENSA.md` (guion, plan B, 16 preguntas) |

## 3. Lo pedido al inicio

| Pedido | Dónde está | Prueba |
|---|---|---|
| Catálogo con el precio del día, que el dueño cambia | `ui/catalogo`, `ui/almacen`, `CatalogoRepository` | `almacen_view_model_test.dart` ("cambiar el precio llega también a la pantalla de comprar") |
| Pagar con tarjeta o Mercado Pago (billetera virtual) | `ui/pago`, `backend/src/pagos.js` (Checkout Pro) | `pago_view_model_test.dart` (10) |
| Ver al repartidor en bicicleta "como el GPS de un taxi" | `mapa_repartidor.dart` (la bici sale de `Almacen`, Gutiérrez 746, y sigue un `Recorrido` por las calles de `RutaServiceOsrm`), `backend/src/seguimiento.js` | "flujo completo: agregar, pagar y ver el seguimiento"; `datos_reales_test.dart` |
| Saber el estado del pedido, también con la app cerrada | Push (FCM) + notificaciones locales | `notificaciones_test.dart` (21) |
| Cargar productos con una foto e IA | `ui/escaner`; ML Kit en el celular (`etiquetado_dispositivo_service.dart` + `lector_de_etiqueta.dart`) o Gemini en el servidor (`backend/src/ia.js`); el precio lo pone el dueño | `escaner_view_model_test.dart`, `datos_reales_test.dart` |
| Fácil para clientes mayores | Barra de 3 botones, letra grande, botones de 56 dp | `widget_test.dart` |
| 5.000 pedidos simultáneos sin pagar servidores | Incompatible; dimensionado para **100 por día y 100 por minuto** con tope en el servidor (`cupo.js`) y aviso claro en la app | `cupo.test.js` (5), "tope de 100 pedidos" (4), `carga.mjs` |

### Correcciones de la profesora (07/11)

| Pedido | Dónde está | Prueba |
|---|---|---|
| "Ojo" para ver la contraseña | `campo_clave.dart` (`obscureText: !_visible`) | "el ojo muestra y oculta la contraseña" |
| Recuperar la contraseña | `recuperar_clave_*`, `backend/src/recuperacion.js` | "recuperar la contraseña y entrar con la nueva" |
| Tocar el mapa y que traiga esa dirección | `elegir_ubicacion_screen.dart` (`onTap`) → la calle real del punto (Nominatim) | `elegir_ubicacion_view_model_test.dart`, `datos_reales_test.dart` |
| Diagrama de clases | `docs/diagramas/clases.png`, `docs/ARQUITECTURA.md` | — |
| MVC sin romper el encapsulamiento | Sección 1 de este informe | `observer_test.dart` + la prueba nueva |
| SQL | `backend/sql/schema.sql` y `seed.sql`; SQLite en el celular (tablas `pedidos` y `carrito`) | `historial_dao_test.dart`, `persistencia_local_test.dart`, `carrito_guardado_test.dart` |

## 4. Riesgos de celular real (corregidos)

Estos problemas no los detecta `flutter test`: aparecen solo en el APK
release o en un iPhone.

1. **Ícono de las notificaciones.** Usaba el ícono de la app
   (`@mipmap/ic_launcher`), que desde la generación de íconos es
   adaptativo y a color. En Android 8.0 eso hace fallar la notificación y
   en las versiones nuevas se ve un cuadrado gris. Ahora hay una silueta
   blanca propia (`res/drawable/ic_notificacion.xml`), usada también por
   los push de Firebase. Además, `res/raw/keep.xml` evita que R8 la borre
   en release: como solo se nombra desde Dart, la daría por no usada.
2. **iOS.** Faltaba asignar el delegado de notificaciones en
   `AppDelegate.swift`. Sin él, iOS no muestra los avisos con la app abierta.
   Se copió la configuración del ejemplo oficial del plugin.

## 5. Lo que queda

Hecho desde el 15/11: las pruebas corridas en la PC (**200** en verde y
`flutter analyze` limpio) y el APK release recompilado con ML Kit.

1. **F2: capturas en un celular Android real**, siguiendo el paso 11 de
   `docs/GUIA_APK_DESDE_CERO.md`. Es lo único que falta para tener los 18
   criterios con evidencia.
2. **Antes de la EGI:** `git pull`, volver a instalar el APK de `main` en el
   celular y tener el proyecto abierto en VS Code.
3. **Producción** (fuera del alcance del trabajo): servidor con https,
   credenciales reales de Mercado Pago y un correo real (`SMTP_URL`).

No se pudo comprobar: la compilación en una Mac (iOS).
