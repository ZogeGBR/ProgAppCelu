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
| 37 pruebas de la app (antes 9) | Pruebas con fakes, sin internet | `test/*` |

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
- Sección "Cargar" (solo para el dueño). Un botón grande: **Sacar foto**.
- La foto viaja al backend, que la analiza con **Gemini** y devuelve nombre,
  categoría, precio sugerido, descripción y emoji. El backend limpia la
  respuesta (nunca confía en la IA tal cual).
- Don Ceferino solo revisa: el precio se puede corregir y la categoría se
  elige con botones. **Nada se guarda hasta que toca "Guardar producto".**

### Pagos con Mercado Pago
- Tres opciones grandes y claras: **tarjeta de débito, tarjeta de crédito y
  dinero en Mercado Pago**.
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
  **Comprar · Mi carrito · Mi pedido** (+ **Cargar** para el dueño).
- Letra más grande, botones de 56 dp, botón "Agregar" de todo el ancho.
- Textos cortos y sin palabras técnicas ("Revisá tu conexión a internet y
  probá otra vez", "No se cobró nada").
- Todas las esperas dicen qué se está esperando y todos los errores tienen
  un botón para seguir. Se sacó el "deslizar para borrar" (difícil de
  descubrir): ahora se quita con el botón "−", que en 1 se vuelve un tacho.

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
| Backend (`cd backend && npm test`) | 12: catálogo, total recalculado, validaciones, estados de pago, firma del webhook, simulación del reparto, posición real con clave, IA | **12/12 pasan** |
| App: caracterización | 4 | No se pudieron correr en el entorno donde se hizo el cambio (sin acceso al SDK de Flutter): **correr `flutter test`** |
| App: `CarritoViewModel` | 8 | ídem |
| App: `CatalogoViewModel` (caché, reintento, error, filtros) | 6 | ídem |
| App: `PagoViewModel` (aprobado, rechazado, error, sin confirmar) | 6 | ídem |
| App: `SeguimientoViewModel` (mapa, corte de señal, entregado) | 4 | ídem |
| App: `EscanerViewModel` (foto, edición, guardar, IA falla) | 5 | ídem |
| App: flujo completo de pantallas | 4 | ídem |

Para validar: `flutter pub get`, `dart format .`, `flutter analyze` y
`flutter test`. Si algún aviso aparece, corregirlo antes de entregar.

## 5. Qué faltaría

| Pendiente | Por qué | Prioridad |
|---|---|---|
| Correr `flutter analyze` y `flutter test` y probar en un celular real | El código no se pudo compilar en el entorno donde se escribió | Alta |
| Base de datos (por ej. PostgreSQL o Firestore) | El backend guarda todo en memoria: al reiniciar se pierden pedidos y productos | Alta |
| Publicar el backend con **https** | Mercado Pago necesita una URL pública para avisar los pagos y volver a la app | Alta |
| App (o modo) del repartidor que mande su GPS | El endpoint ya existe; falta la app con `geolocator` y permiso de ubicación en segundo plano | Alta |
| Dirección de entrega del cliente | Hoy el destino del mapa es fijo (demo); falta pedir la dirección y ubicarla en el mapa | Alta |
| Login y roles (cliente / dueño / repartidor) | Hoy la sección del dueño se oculta con `MODO_DUENO=false`, no con usuarios | Alta |
| **5.000 pedidos simultáneos sin pagar servidores** | Son pedidos incompatibles: ese volumen necesita infraestructura (servidores, base de datos, balanceo) que cuesta. Hay que presentarle a Don Ceferino un plan con costo mínimo (hosting con escalado automático) | Alta |
| Volver solo a la app después de pagar (deep link) | Hoy vuelve con una página web y la app detecta el pago consultando | Media |
| Notificaciones push ("tu pedido está en camino") | Avisar sin tener la app abierta (Firebase Cloud Messaging) | Media |
| Editar precios del día, stock y borrar productos | Don Ceferino cambia precios seguido | Media |
| Guardar la foto del producto y mostrarla en el catálogo | Hoy el catálogo usa emojis | Media |
| Proveedor de mapas para producción | Los mosaicos públicos de OpenStreetMap tienen límite de uso justo; con muchos usuarios conviene MapTiler, Stadia o un caché propio | Media |
| Pruebas de usabilidad con clientes reales del almacén | Confirmar que personas mayores completan una compra sin ayuda | Media |
| Credenciales de producción de Mercado Pago y devoluciones | Hoy se prueba con credenciales de prueba; falta el flujo de reembolso | Media |
| Costos | Mercado Pago cobra comisión por venta; Gemini tiene un nivel gratis con límites; el hosting tiene costo mensual | Baja |
| Accesibilidad avanzada | Etiquetas `Semantics` para lector de pantalla y prueba con letra al 200 % | Baja |
| Pago en efectivo al recibir | Varios clientes de barrio lo prefieren | Baja |
| Publicar en Play Store | Firma, íconos y política de privacidad (usa la cámara) | Baja |
| Reescribir `EXPLICACION_CODIGO.md` archivo por archivo para la V3 | Hoy tiene una tabla de equivalencias V2 → V3 al principio | Baja |
