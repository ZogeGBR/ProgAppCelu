# Demo y defensa (criterio G1)

Presentación del 19/11 · 10 minutos de demo + preguntas.

> **EGI (Comisión B 26/11, Comisión A 3/12, desde las 14 h):** no es una
> exposición ni lleva PowerPoint. La profesora pregunta por **el código**
> (cómo está organizado, qué decisiones se tomaron y por qué) y por **los
> requerimientos** (cuáles eran y cómo se resolvieron), con la app
> funcionando y el proyecto abierto. Llevar las certificaciones de Claude.
> El guion de abajo sirve como recorrido de la app; las preguntas siguen
> valiendo.

## Antes de entrar

- [ ] Dos celulares cargados: uno de **cliente** y otro de **Don Ceferino /
      repartidor**, con el APK nuevo instalado.
- [ ] El backend corriendo en la PC (`node --env-file=.env src/server.js`)
      y los celulares en el **mismo Wi-Fi** (ver `docs/CELULAR_REAL.md`).
- [ ] Datos de demo: el catálogo de ejemplo, un pedido anterior en el
      historial (hacer una compra el día antes) y la cuenta del dueño
      creada.
- [ ] **Plan B sin internet**: el APK de la demo (compilado sin
      `URL_BACKEND`) no necesita servidor propio. Con internet muestra la
      calle real del mapa y la bici por las calles; sin internet, la
      dirección se escribe a mano y la bici va en línea recta. La foto del
      producto se lee en el celular y anda igual sin internet.
- [ ] `flutter test` y `npm test` corridos esa mañana (captura en el celular
      por si lo piden).
- [ ] Proyector: la app en el celular espejada (scrcpy o Android Studio) y
      el código abierto en VS Code en las carpetas que se van a mostrar.

## Guion (10 minutos)

| Min | Quién (sugerido) | Qué se muestra | Criterios |
|---|---|---|---|
| 0–1 | Zoe | El problema de Don Ceferino y la respuesta: clientes mayores, pedidos por WhatsApp, reparto en bici. Tabla "De la entrevista al código" | A1 |
| 1–3 | Matías | **Cliente**: buscar, categorías, mantener apretado un producto (detalle), agregar, deslizar un renglón del carrito y "Deshacer". Girar el celular o mostrar en tablet: la grilla | B1, B3, B4 |
| 3–5 | Matías | Pagar: marcar la casa tocando el mapa (la dirección aparece sola), elegir medio, Mercado Pago, "Mi pedido" con la bici moviéndose en el mapa | F1, D2, D3 |
| 5–6 | Ignacio | **Celular del dueño**: llega la notificación "Nuevo pedido" (push). Repartidor: sale, el cliente recibe "En camino" con la app cerrada | E1 |
| 6–7 | Ignacio | Salir de la app con el carrito lleno (se programa el recordatorio); cortar el Wi-Fi: aparece "Sin internet" y se va solo al volver | E2, E3 |
| 7–8 | Zoe | Cerrar la app del todo y volver a abrirla: el carrito sigue (SQLite). "Volver a pedir" desde el historial. Apagar el efectivo en el servidor (`FUNCIONES_APAGADAS=pagoEnEfectivo`), reabrir: ya no aparece | F1, D1 |
| 8–10 | Zoe | Código: diagrama de capas, `Politicas`, `BaseLocal` con sus dos DAO, un test. Correr `flutter test` en vivo | C1–C4 |

## 18 preguntas probables (con respuesta corta)

1. **¿Por qué MVVM y no MVC?** — Es la versión de MVC que usa Flutter: la
   vista *observa* al ViewModel (`ListenableBuilder` + `notifyListeners`), así
   el ViewModel no conoce widgets y se prueba sin pantalla. El ViewModel
   cumple el rol del Controlador.
2. **¿Qué pasa si un ViewModel necesita algo de otro?** — No se llaman entre
   sí: los dos observan al mismo repositorio. Por ejemplo, al aprobarse un
   pago, `PagoRepository` lo publica y el carrito se vacía y "Mi pedido"
   empieza a seguirlo.
3. **¿Dónde usan Singleton?** — En el backend (una sola conexión a la base).
   En la app no hay clases con `static instancia`: `Dependencias` crea una
   sola instancia de cada cosa y la pasa por constructor, que se puede
   reemplazar en las pruebas.
4. **¿Para qué la clase Politicas si alcanza con `Platform.isAndroid`?** —
   `Platform.isX` dice dónde corre, no por qué se decide, termina copiado en
   diez lugares y rompe en Web. Un getter con nombre de negocio decide en un
   lugar y se prueba con `debugDefaultTargetPlatformOverride`.
5. **¿`async` saca el trabajo del hilo principal?** — No. Solo libera el hilo
   mientras espera. Para *calcular* algo pesado (la foto a base64) usamos
   `Isolate.run`.
6. **¿Por qué `Future.wait` en el arranque?** — Son cinco cargas
   independientes: en paralelo tarda la más lenta, no la suma.
7. **¿Qué pasa si se olvida un `await`?** — El `try` termina antes que el
   Future y el error no pasa por el `catch`: la app marcaría "éxito" sin
   confirmar. Por eso el lint `unawaited_futures`.
8. **¿Por qué el aviso de "Sin internet" no reemplaza el manejo de
   errores?** — Tener red no es tener internet (un Wi-Fi con login). El aviso
   informa; cada llamada igual tiene timeout y "Reintentar".
9. **¿Cómo llega una notificación con la app cerrada?** — La muestra el
   sistema operativo. Si se toca, la app la recibe con `getInitialMessage`;
   con la app en segundo plano, con `onMessageOpenedApp`; abierta, con
   `onMessage` (y la mostramos con una notificación local).
10. **¿Por qué `zonedSchedule` y no `workmanager`?** — Para "a tal hora
    mostrá este aviso" no hace falta correr Dart: lo hace el sistema.
    `workmanager` es para correr código, y no tenemos trabajo para hacer sin
    la persona.
11. **¿Qué guardan en SQLite y qué en preferencias?** — Depende de la forma
    del dato. El **carrito** y el **historial** son listas de objetos: van a
    tablas de SQLite (`CarritoDao` y `HistorialDao`, en la misma base). El
    **pedido en curso** es un solo objeto chico: va a `SharedPreferencesAsync`.
    Al principio el carrito iba como JSON en preferencias; lo pasamos a una
    tabla porque el apunte marca justamente eso como señal de usar una base.
    En la web, donde no hay SQLite, `Politicas` elige preferencias.
12. **¿Qué pasa con los celulares que tenían la versión anterior de la
    base?** — `onCreate` no se vuelve a ejecutar; corre `onUpgrade`: de la
    1 a la 2 agrega la columna `direccion` y de la 2 a la 3 crea la tabla
    `carrito`. Hay pruebas de las dos migraciones.
13. **¿Cómo evitan la inyección SQL?** — Siempre con `?` y `whereArgs`, nunca
    pegando texto. Y nunca `DELETE` sin `WHERE`.
14. **¿Cómo protegen las claves?** — Ninguna va en la app: Mercado Pago,
    Gemini y Firebase viven en el backend (`.env`). Las contraseñas se guardan
    como huella scrypt con sal. La llave de firma del APK está fuera del repo.
15. **¿Qué no llegaron a hacer?** — GPS del repartidor con la pantalla
    apagada (servicio en primer plano, permisos que Play revisa a mano),
    hosting con https para producción y publicación abierta en Play Store
    (quedó lista la prueba interna). Está en "Qué faltaría".
16. **¿Cuántos pedidos aguanta? Don Ceferino pidió 5.000.** — 5.000
    simultáneos sin pagar servidores es incompatible. Un almacén de barrio
    recibe hasta unos 100 pedidos por día (el límite real son los
    repartidores en bici), así que lo dimensionamos para **100 por día y 100
    por minuto**: alcanza un servidor chico y barato. El tope lo hace
    cumplir el servidor (`cupo.js`) y la app avisa "Por hoy ya no tomamos
    más pedidos" o "Probá en un minuto", sin cobrar. Probado con 100
    clientes a la vez: 0 errores.
17. **¿Qué pasa si se niega el permiso de la cámara, o si se cancela?** —
    Cancelar devuelve `null` y no pasa nada. Un error real (sin permiso, sin
    cámara) el servicio lo traduce a `ErrorDeFoto`, que vive en el dominio,
    y la pantalla muestra un mensaje claro. Si Android cierra la app con la
    cámara abierta, al volver `retrieveLostData` recupera la foto.
18. **¿Cómo sabe la app qué producto es la foto?** — ML Kit, en el celular
    y sin internet: lee el texto del envase y reconoce la imagen.
    `LectorDeEtiqueta` toma el texto más grande como nombre y elige la
    categoría. El precio no lo adivina: lo pone siempre el dueño.
