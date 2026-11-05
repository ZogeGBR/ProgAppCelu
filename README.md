# FreshMarket — App de pedidos para el almacén de Don Ceferino

App **Flutter/Dart** del trabajo práctico de *Programación de Aplicaciones
para Celulares* (ITU), a partir de la entrevista a Don Ceferino, dueño de
FreshMarket (almacén de barrio).

**Versión 3:** arquitectura en capas (MVVM), mapa con el repartidor en
bicicleta en tiempo real, carga de productos con una foto (IA), pagos con
Mercado Pago (débito, crédito y dinero en cuenta) y una navegación pensada
para personas que no usan mucho el celular. El detalle de qué se mejoró y
qué falta está en [`INFORME_MEJORAS.md`](INFORME_MEJORAS.md).

## Cómo correrlo

### 1. Solo la app (modo demo, sin claves)

```bash
flutter pub get
flutter run
```

Sin configuración, todo funciona **simulado**: catálogo de ejemplo, pago
que se aprueba solo, repartidor que recorre el centro de Mendoza y una IA
que devuelve una etiqueta de ejemplo. La cámara sí es real.

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
| `CLAVE_REPARTIDOR` | Que solo la app del repartidor pueda mandar su posición | Cualquiera puede mandarla |

> **Seguridad:** ninguna clave va en la app Flutter. La app solo conoce
> `URL_BACKEND`. El backend recalcula el total con sus propios precios,
> así que nadie puede pagar menos modificando la app.

Para ocultar la sección del dueño en la versión para clientes:
`--dart-define=MODO_DUENO=false`.

### Pruebas y calidad

```bash
dart format .
flutter analyze
flutter test           # app: ViewModels con fakes + flujo completo
cd backend && npm test # backend: 12 pruebas
```

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
│   │   └── camara_service.dart      (image_picker)
│   └── repositories/            ← JSON → modelo, caché, reintentos, esperas
└── ui/
    ├── core/                    ← tema accesible, formato de precios, VistaMensaje
    ├── inicio/                  ← barra de abajo (NavegacionViewModel)
    ├── catalogo/                ← "Comprar"
    ├── carrito/                 ← "Mi carrito" (CarritoViewModel)
    ├── pago/                    ← pago con Mercado Pago
    ├── seguimiento/             ← "Mi pedido" con el mapa del repartidor
    └── escaner/                 ← "Cargar": producto nuevo con una foto
backend/                         ← Node + Express (claves, pagos, IA, reparto)
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
- **Antes de cada commit:** `dart format .`, `flutter analyze` y `flutter test`.

## De la entrevista al código

| Pedido de Don Ceferino | Dónde se resuelve |
|---|---|
| Ver el catálogo con precio del día | `ui/catalogo` + `CatalogoRepository` (backend o local) |
| Pagar "con tarjeta o Mercado Pago" | `ui/pago` + `PagoRepository` + `backend/src/pagos.js` (Checkout Pro) |
| Ver el reparto "como el GPS de un taxi" | `ui/seguimiento/widgets/mapa_repartidor.dart` + `backend/src/seguimiento.js` |
| Cargar productos sin saber de tecnología | `ui/escaner` + `backend/src/ia.js` (foto → etiqueta) |
| Que sea fácil para clientes mayores | `ui/inicio` (barra de 3 botones) + `ui/core/tema.dart` |
| 5.000 pedidos simultáneos en diciembre, sin pagar servidores | **Incompatibles**: ver `INFORME_MEJORAS.md`, sección "Qué faltaría" |
