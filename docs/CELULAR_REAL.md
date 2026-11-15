# Probar FreshMarket en un celular real (para la EGI)

Criterio **F2 de la grilla: "Testing en dispositivo real y publicación"**.
Hay tres formas, de la más simple a la más completa.

## Opción A: APK de la demo (sin backend, sin cables)

Todo simulado (pago, repartidor, IA), pero la **cámara, el GPS, el mapa y
las notificaciones son reales**. Es la más segura para mostrar en clase
porque no depende del Wi-Fi.

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`
(~60 MB). Para pasarlo al celular:

1. Mandarlo por WhatsApp/Drive/cable y abrirlo en el celular.
2. Android pregunta si se permite **instalar apps de origen desconocido**
   para esa app (Drive, WhatsApp, Archivos): aceptar. Es porque no viene de
   Play Store.
3. Si aparece **Play Protect** ("app no reconocida"): "Instalar de todas
   formas". Pasa porque está firmada con la clave de prueba (ver "Publicación").

## Opción B: APK + backend en la PC (misma red Wi-Fi)

Para mostrar los pagos, el dueño, el repartidor y las notificaciones push
entre **dos celulares**.

1. En la PC, averiguar la IP local: `ipconfig` → "Dirección IPv4" del
   adaptador Wi-Fi (por ejemplo `192.168.0.15`).
2. Arrancar el backend (`cd backend && node --env-file=.env src/server.js`).
   La primera vez Windows pregunta por el **firewall**: permitir en redes
   privadas. Probar desde el navegador del celular:
   `http://192.168.0.15:3000/salud` tiene que responder `{"ok":true,...}`.
3. Compilar la app apuntando a esa IP:

   ```bash
   flutter build apk --release --dart-define=URL_BACKEND=http://192.168.0.15:3000
   ```

4. Instalar como en la opción A.

> La app habla por `http` (sin `s`) con la PC gracias a
> `android:usesCleartextTraffic="true"` en el `AndroidManifest.xml`. En
> producción el backend iría con `https` y eso se saca.
>
> En la facultad, si la red no deja que los celulares se vean con la PC,
> usar el **hotspot de un celular** y conectar la PC a ese hotspot.

Para las notificaciones push hace falta además configurar Firebase una vez:
ver [`NOTIFICACIONES.md`](NOTIFICACIONES.md), sección 4.

## Opción C: con cable, para desarrollar

1. En el celular: Ajustes → Acerca del teléfono → tocar 7 veces "Número de
   compilación" → aparece **Opciones de desarrollador** → activar
   **Depuración USB**.
2. Conectar por USB y aceptar el cartel "¿Permitir depuración USB?".
3. `flutter devices` tiene que mostrar el celular.
4. `flutter run --release` (o con `--dart-define=URL_BACKEND=...`).

## Qué probar en el celular (y en el emulador no se puede)

| Qué | Cómo | Esperado |
|---|---|---|
| Cámara | Dueño → "Mi almacén" → "Cargar producto con una foto" | Abre la cámara de verdad; la IA propone nombre y precio |
| GPS | Pago → "Marcar mi casa en el mapa" → "Usar mi ubicación" | El mapa se centra donde estás y escribe la calle |
| Permisos negados | Negar ubicación o notificaciones | La app no se cae y explica qué falta |
| Notificaciones | Hacer un pedido y esperar (demo: ~6 s) | "Tu pedido está en camino" en la barra, también con la app minimizada; al tocarla abre "Mi pedido" |
| Segundo plano | Agregar al carrito, salir con el botón de inicio, cerrar la app desde recientes y volver a abrir | El carrito sigue ahí (`AppLifecycleListener`) |
| Mercado Pago | Pagar con débito (backend real) | Abre la app de Mercado Pago o el navegador |
| Letra grande | Ajustes → Pantalla → Tamaño de fuente al máximo | Nada se corta ni se superpone |
| Modo oscuro | Activarlo en el sistema | Se sigue leyendo bien |
| Sin internet | Modo avión en "Comprar" (con backend) | "Revisá tu conexión a internet" con "Reintentar" |

## Publicación

La firma con llave propia (`android/key.properties`, fuera del repo), el App
Bundle y la prueba interna en Play Console están en
[`PUBLICACION.md`](PUBLICACION.md). Sin `key.properties` el APK se firma
con la llave de prueba, que alcanza para instalarlo a mano.

La guía completa para alguien que arranca sin nada instalado está en
[`GUIA_APK_DESDE_CERO.md`](GUIA_APK_DESDE_CERO.md).
