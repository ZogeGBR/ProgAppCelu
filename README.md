# FreshMarket — App de pedidos para el almacén de Don Ceferino

App **Flutter/Dart** del trabajo práctico de *Programación de Aplicaciones
para Celulares* (ITU), a partir de la entrevista a Don Ceferino, dueño de
FreshMarket (almacén de barrio).

**Versión 3:** arquitectura en capas (MVVM), mapa con el repartidor en
bicicleta en tiempo real, carga de productos con una foto (IA), pagos con
Mercado Pago (débito, crédito y dinero en cuenta) o en efectivo al recibir,
dirección de entrega, modo repartidor con GPS, administración del almacén y
una navegación pensada para personas que no usan mucho el celular.

Además: cuentas con email y contraseña (con el **ojo** para ver lo que se
escribe y **recuperación por código**), **dirección automática** al tocar el
mapa y carrito guardado en el celular.

- Qué se mejoró y qué falta: [`INFORME_MEJORAS.md`](INFORME_MEJORAS.md).
- Teoría de la materia y patrones (dónde se usa cada uno y por qué no los
  otros): [`INFORME_TEORIA_Y_PATRONES.md`](INFORME_TEORIA_Y_PATRONES.md).
- Diagramas de capas, de clases y de la base de datos:
  [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).

## Cómo correrlo

### 1. Solo la app (modo demo, sin claves)

```bash
flutter pub get
flutter run
```

Sin configuración, todo funciona **simulado**: catálogo de ejemplo, pago
que se aprueba solo, repartidor que recorre el centro de Mendoza y una IA
que devuelve una etiqueta de ejemplo. La cámara y el GPS sí son reales.

Para entrar como dueño o repartidor: ícono del almacén arriba a la derecha en
"Comprar", email `dueno@freshmarket.com` o `repartidor@freshmarket.com`,
contraseña `freshmarket`. En "¿Olvidaste tu contraseña?" el código de la demo
es `123456`.

### 2. App + backend (pagos y mapa reales)

```bash
cd backend
npm install
cp .env.example .env      # completar las claves (ver abajo)
node --env-file=.env src/server.js
```

En otra terminal, desde la raíz del proyecto:

```bash
# Emulador de Android: 10.0.2.2 es "localhost" de la PC.
flutter run --dart-define=URL_BACKEND=http://10.0.2.2:3000
```

| Variable (`backend/.env`) | Para qué | Sin ella |
|---|---|---|
| `MP_ACCESS_TOKEN` | Crear pagos reales en Mercado Pago (usar credenciales **de prueba** para desarrollar) | Pago simulado: se abre una página que lo aprueba |
| `MP_WEBHOOK_SECRET` | Validar la firma de los avisos de Mercado Pago | No se valida la firma |
| `URL_PUBLICA` | URL **https** del backend, para que Mercado Pago avise y vuelva a la app | La app igual consulta el estado cada 3 s |
| `GEMINI_API_KEY` | Reconocer productos con IA (Google AI Studio) | Etiqueta de ejemplo |
| `DUENO_EMAIL` y `DUENO_CLAVE` | Crear la cuenta del dueño la **primera vez** que arranca (contraseña de 8 caracteres o más). Después se cambia desde la app | Nadie puede entrar como dueño |
| `REPARTIDOR_EMAIL` y `REPARTIDOR_CLAVE` | Igual, para el repartidor | Nadie puede entrar como repartidor |
| `SMTP_URL` | Mandar por email el código para recuperar la contraseña (por ej. `smtps://usuario:clave@smtp.gmail.com:465`) | El código aparece en la consola del servidor |
| `GOOGLE_MAPS_API_KEY` | Buscar la dirección de un punto del mapa con Google | Se usa Nominatim (OpenStreetMap), gratis |
| `CONTACTO_MAPAS` | Email o web que Nominatim pide para identificar la app | Se manda un nombre genérico |
| `GEOCODIFICACION` | `simulado` para trabajar sin internet | `nominatim` |
| `SECRETO_SESION` | Firmar las sesiones | Se genera al arrancar: hay que volver a ingresar en cada reinicio |
| `SIMULAR_REPARTO` | `true` o `false`: simular al repartidor mientras no mande su GPS | Se simula solo si Mercado Pago también está simulado |
| `RUTA_BD` | Archivo de la base de datos (SQLite) | `freshmarket.db` |

Hace falta **Node 22.13 o más nuevo**, que ya trae SQLite. El esquema de la
base está en [`backend/sql/schema.sql`](backend/sql/schema.sql) y los datos
iniciales en [`backend/sql/seed.sql`](backend/sql/seed.sql). La base se crea
sola al arrancar, o a mano con `cd backend && npm run bd:crear`.

> **Seguridad:** ninguna clave va en la app Flutter. La app solo conoce
> `URL_BACKEND`. El backend recalcula el total con sus propios precios,
> así que nadie puede pagar menos modificando la app.

### Pruebas y calidad

```bash
dart format lib test
flutter analyze
flutter test           # app: 90 pruebas (ViewModels con fakes y pantallas)
cd backend && npm test # backend: 34 pruebas
node scripts/carga.mjs 500   # (desde backend/) prueba de carga
```

> `dart format .` falla después de compilar porque entra a `build/`: por eso se
> indican las carpetas.

> **Ojo con la ruta en Windows:** si la carpeta tiene tildes o símbolos
> (por ej. `5° Semestre\Programación...`), el Android Gradle Plugin corta
> el build. Por eso `android/gradle.properties` tiene
> `android.overridePathCheck=true`. Si el analizador se cuelga, copiar el
> proyecto a una ruta sin tildes (por ej. `C:\dev\freshmarket`).

## Estructura (arquitectura en capas)

```
lib/
├── main.dart                    ← crea los ViewModels una vez y arma la app
├── config/
│   └── dependencias.dart        ← ÚNICO lugar donde se elige real o simulado
├── domain/models/               ← datos puros: Producto, Pedido, Posicion...
├── data/
│   ├── services/                ← hablan con afuera, sin estado
│   │   ├── api_client.dart          (HTTP con tiempo límite)
│   │   ├── catalogo_service.dart    (backend / local)
│   │   ├── pago_service.dart        (Mercado Pago vía backend / simulado)
│   │   ├── seguimiento_service.dart (backend cada 3 s / simulado)
│   │   ├── etiquetado_service.dart  (IA vía backend / simulada)
│   │   ├── sesion_service.dart      (ingreso y recuperación de contraseña)
│   │   ├── geocodificacion_service.dart (punto del mapa → calle y número)
│   │   ├── carrito_local_service.dart   (carrito guardado en el celular)
│   │   ├── reparto_service.dart     (pedidos y posición del repartidor)
│   │   ├── ubicacion_service.dart   (GPS con geolocator)
│   │   └── camara_service.dart      (image_picker)
│   └── repositories/            ← JSON → modelo, caché, reintentos, esperas
└── ui/
    ├── core/                    ← tema accesible, formato de precios, VistaMensaje, CampoClave
    ├── inicio/                  ← barra de abajo (NavegacionViewModel)
    ├── catalogo/                ← "Comprar"
    ├── carrito/                 ← "Mi carrito" (CarritoViewModel)
    ├── pago/                    ← pago con Mercado Pago y mapa para marcar la casa
    ├── seguimiento/             ← "Mi pedido" con el mapa del repartidor
    ├── escaner/                 ← producto nuevo con una foto
    ├── sesion/                  ← ingreso y "¿Olvidaste tu contraseña?"
    ├── almacen/                 ← "Mi almacén": precios, sin stock, borrar
    └── reparto/                 ← "Repartir": pedidos y envío del GPS
backend/                         ← Node + Express + SQLite (pagos, IA, reparto, cuentas, mapa)
├── sql/                         ← schema.sql y seed.sql
docs/                            ← ARQUITECTURA.md y diagramas
test/                            ← pruebas con fakes (sin internet)
```

```
Vista (Screen)  ──llama comandos──▶  ViewModel (ChangeNotifier)
      ▲  escucha (ListenableBuilder)        │
      └─────────────────────────────────────┘
                                            ▼
                                     Repositorio  (caché, reintento, conversión)
                                            ▼
                                       Servicio    (red, cámara; sin estado)
                                            ▼
                         Backend propio ──▶ Mercado Pago / Gemini / repartidor
```

## Convenciones

- **Idioma:** español para el dominio (`Producto`, `Pedido`,
  `agregarProducto()`) e inglés solo para lo que viene de Flutter (`build`,
  `Widget`, `notifyListeners`). Sin tildes ni ñ en los nombres.
- **Nombres:** clases en `UpperCamelCase`, archivos en
  `lowercase_with_underscores`, constantes en `lowerCamelCase`. Booleanos en
  positivo (`estaVacio`, `puedePagar`).
- **Piezas por sección:** `<Seccion>Screen` y widgets en
  `ui/<seccion>/widgets/`, `<Seccion>ViewModel` en
  `ui/<seccion>/view_models/`. Partes de una sola pantalla como clases
  privadas en el mismo archivo (`_ResumenTotal`).
- **Capas:** las vistas no hablan con la red; los ViewModels importan solo
  `foundation.dart`; los servicios no guardan estado; los repositorios no
  dependen entre sí. Las dependencias se reciben por el constructor.
- **Verbos:** `cargar`, `agregar`, `quitar`, `eliminar`, `vaciar`, `armar`,
  `pagar`, `seguir`. Consultas con sustantivo (`total`, `cantidadDe`).
- **Async:** toda espera muestra carga, maneja el error con "Reintentar" y
  tiene tiempo límite. Después de un `await`, chequear `mounted`.
- **Textos de pantalla:** cortos, sin palabras técnicas, botones de al menos
  56 dp con ícono y texto.
- **Antes de cada commit:** `dart format lib test`, `flutter analyze` y
  `flutter test`.

## De la entrevista al código

| Pedido de Don Ceferino | Dónde se resuelve |
|---|---|
| Ver el catálogo con precio del día | `ui/catalogo` + `CatalogoRepository` (backend o local); el dueño lo cambia en `ui/almacen` |
| Pagar "con tarjeta o Mercado Pago" | `ui/pago` + `PagoRepository` + `backend/src/pagos.js` (Checkout Pro) |
| Ver el reparto "como el GPS de un taxi" | `ui/seguimiento/widgets/mapa_repartidor.dart` + `backend/src/seguimiento.js` |
| Cargar productos sin saber de tecnología | `ui/escaner` + `backend/src/ia.js` (foto → etiqueta) |
| Que sea fácil para clientes mayores | `ui/inicio` (barra de 3 botones) + `ui/core/tema.dart` |
| 5.000 pedidos simultáneos en Nochebuena, sin pagar servidores | **Incompatibles.** Con la profesora acordamos un pico realista de hasta 500: ver `INFORME_MEJORAS.md`, secciones "Pruebas" y "Qué faltaría" |
