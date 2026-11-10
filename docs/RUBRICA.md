# FreshMarket frente a la rúbrica EGI

Grupo: García Badiola · Lopez · Morichetti Ramal. Presentación: 19/11.

Para cada criterio: **qué mostrar** (en menos de un minuto), **dónde está**
en el código y **qué prueba** lo respalda. Escala: 3 Logrado · 2 En proceso
· 1 Inicial · 0 No presenta.

| | Criterio | Qué mostrar en la defensa | Dónde está | Pruebas |
|---|---|---|---|---|
| **A1** | Alcance y respuesta al cliente | La tabla "De la entrevista al código" del README: cada pedido de Don Ceferino resuelto o justificado (los 5.000 pedidos simultáneos sin servidores no se pueden cumplir; se acordó un pico de 500 y se probó) | `README.md`, `INFORME_MEJORAS.md` | `backend/scripts/carga.mjs` |
| **B1** | Interfaz: widgets y composición | Widgets propios reutilizables: `VistaMensaje`, `CampoClave`, `SelectorCantidad`, `ProductoCard`, `AvisoSinInternet`, `HistorialDePedidos`. Tema accesible (letra grande, botones de 56 dp). Logo propio declarado en `assets` | `lib/ui/core/`, `lib/ui/*/widgets/` | `widget_test.dart`, `presentacion_final_test.dart` |
| **B2** | Estado y ciclo de vida | `StatefulWidget` con `initState` (controllers, listeners), `didUpdateWidget` (mapa que sigue a la bici) y `dispose` (todo se cierra). Estado de la app en ViewModels; estado de la vista (el ojo de la contraseña) en el `State` | `campo_clave.dart`, `mapa_repartidor.dart`, `elegir_ubicacion_screen.dart`, `main.dart` | todas las de pantallas |
| **B3** | Interacción y navegación | **Rutas con nombre** (`Rutas` + `onGenerateRoute`), `NavigationBar` + `IndexedStack`, pantallas que devuelven resultado (el mapa devuelve la dirección), `PopScope` durante el pago. **Gestos**: mantener apretado un producto, deslizar un renglón del carrito (con "Deshacer"), tirar para recargar | `lib/ui/core/rutas.dart`, `main.dart`, `catalogo_screen.dart`, `carrito_screen.dart` | `presentacion_final_test.dart` |
| **B4** | Configuración multiplataforma | `namespace`/`applicationId` propios, permisos en `AndroidManifest.xml` e `Info.plist` con el **motivo** de cada uno, ícono adaptativo (`flutter_launcher_icons`), splash (`flutter_native_splash`), nombre "FreshMarket" en Android e iOS, versión `1.1.0+2`, **diseño adaptativo** (grilla desde 840 de ancho) | `pubspec.yaml`, `android/`, `ios/Runner/Info.plist`, `assets/icono/` | grilla: `presentacion_final_test.dart` |
| **C1** | Arquitectura en capas | Diagrama de capas y de clases. Reglas verificables: ninguna vista habla con la red, ningún ViewModel importa `material.dart` ni servicios, ningún ViewModel llama a otro (se observan repositorios) | `docs/ARQUITECTURA.md`, `docs/diagramas/` | `observer_test.dart` |
| **C2** | Código limpio y herramientas | Nombres en español consistentes, constantes con nombre, `enum` en vez de números, `switch` de expresión, comentarios que explican el porqué. `dart format`, `flutter analyze` con lints extra (`unawaited_futures`, `use_build_context_synchronously`) | `analysis_options.yaml`, README "Convenciones" | `flutter analyze` sin avisos |
| **C3** | Refactoring | Pruebas de caracterización antes de reorganizar; refactorings nombrados (callbacks → Observer; `confirmarPedido` → `armarPedido` + vaciar; `PermisoUbicacion` al dominio; token privado; rutas con nombre) | `test/caracterizacion_test.dart`, `INFORME_MEJORAS.md`, `INFORME_CAMBIOS_07-11.md` | caracterización |
| **C4** | Pruebas | ViewModels con fakes, pantallas completas, políticas con `debugDefaultTargetPlatformOverride`, SQLite real en memoria (`sqflite_common_ffi`) con migración, backend con `node --test` | `test/`, `backend/test/` | `flutter test`, `npm test` (47) |
| **D1** | Capacidades y políticas | Clase `Politicas` con getters de negocio (`puedeSacarFotos`, `permitePagoEnEfectivo`...), `defaultTargetPlatform`/`kIsWeb`, inyectada por constructor. **Tres chequeos**: al compilar, al ejecutar, desde el servidor (`GET /funciones`, apagar el efectivo con `FUNCIONES_APAGADAS`) | `lib/domain/politicas/politicas.dart`, `backend/src/app.js` | `politicas_test.dart`, `funciones.test.js`, "si el servidor apaga el efectivo" |
| **D2** | Future y async/await | `try/catch/finally`, `timeout` con política por defecto, `Future.wait` en el arranque, `context.mounted` después de cada `await`, respuestas viejas descartadas al tocar el mapa | `funciones_repository.dart`, `historial_view_model.dart`, `main.dart`, `elegir_ubicacion_view_model.dart` | `politicas_test.dart` (timeout), `elegir_ubicacion_view_model_test.dart` |
| **D3** | Streams e Isolates | Streams broadcast en los repositorios (Observer), `Stream.periodic` + `asyncMap` para el seguimiento, `listen` + `cancel` en `dispose`, `distinct()`; `Isolate.run` para pasar la foto a base64 y el isolate de push en segundo plano | `*_repository.dart`, `seguimiento_service.dart`, `etiquetado_service.dart`, `push_service.dart` | `observer_test.dart`, `seguimiento_view_model_test.dart` |
| **E1** | Notificaciones | Push (FCM) en los **4 casos**: `onMessage` (se muestra con local), `onMessageOpenedApp`, `getInitialMessage`, `onBackgroundMessage`. Locales con canal propio, `id` para reemplazar y `payload` que abre la sección correcta. Permiso pedido en contexto | `push_service.dart`, `notificacion_local_service.dart`, `notificaciones_repository.dart`, `docs/NOTIFICACIONES.md` | `notificaciones_test.dart` (21) |
| **E2** | Segundo plano | `zonedSchedule` con `TZDateTime` e `inexactAllowWhileIdle`: "Te quedó un pedido sin terminar" 2 h después de salir con el carrito lleno; receptores para que sobreviva a un reinicio. Manejador de push en otro isolate. `workmanager` justificado como no necesario | `recordatorio_service.dart`, `recordatorios_repository.dart`, `AndroidManifest.xml` | `segundo_plano_y_eventos_test.dart` |
| **E3** | Eventos del sistema | `AppLifecycleListener` (`onHide`/`onPause` guardan y programan; `onShow`/`onResume` cancelan y revisan la red), `connectivity_plus` con aviso "Sin internet", bus de eventos propio (Streams de los repositorios). Todas las suscripciones se cancelan | `main.dart`, `conectividad_*`, `aviso_sin_internet.dart` | `segundo_plano_y_eventos_test.dart`, "sin internet aparece el aviso" |
| **F1** | Persistencia, APIs y cámara | `SharedPreferencesAsync` (carrito, pedido en curso) con patrón Preferencias; **SQLite** con DAO, `toMap/fromMap`, consultas con `?` y migración (`onUpgrade`); SQL del servidor (`backend/sql/schema.sql`). APIs: backend propio, Mercado Pago, Gemini, Nominatim/Google, FCM. Cámara con `image_picker` y permisos | `preferencias.dart`, `historial_dao.dart`, `backend/sql/`, `camara_service.dart` | `historial_dao_test.dart`, `carrito_guardado_test.dart`, `pedido_guardado_test.dart` |
| **F2** | Testing en dispositivo real y publicación | APK release instalado en un celular real, checklist con capturas, firma con llave propia (`key.properties` fuera del repo), App Bundle listo para la prueba interna de Play Console | `docs/CELULAR_REAL.md`, `docs/PUBLICACION.md`, `android/app/build.gradle.kts` | checklist de `docs/PUBLICACION.md` |
| **G1** | Demo y defensa | Guion de 10 minutos, plan B sin internet y 15 preguntas probables con su respuesta | `docs/DEMO_Y_DEFENSA.md` | ensayo |

## Antes de presentar (comandos)

```bash
flutter pub get
dart run flutter_launcher_icons          # ícono
dart run flutter_native_splash:create    # pantalla de arranque
dart format lib test
flutter analyze                          # tiene que dar 0 avisos
flutter test                             # todo en verde
cd backend && npm install && npm test    # 47/47
```
