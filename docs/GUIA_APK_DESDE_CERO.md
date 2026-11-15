# FreshMarket: del repositorio al celular, desde cero

Guía para que cualquiera del grupo, en **su** computadora con Windows y
**su** celular Android, pueda descargar el proyecto, comprobar que anda,
generar el APK, instalarlo y sacar las capturas del criterio **F2**
("Testing en dispositivo real"). Está escrita a partir de lo que pasó la
primera vez que se hizo (15/11), con cada error que apareció y su solución.

- **Tiempo:** 1 h 30 a 2 h la primera vez (casi todo es descarga).
- **Espacio en disco:** unos 20 GB libres.
- **Hace falta:** internet, un celular **Android** y un cable USB que pase
  datos (algunos cables solo cargan).

**Importante: tiene que ser Android.** El APK es el instalador de Android;
un iPhone no lo puede abrir. Ver el final de la guía.

## Paso 1. Instalar Git

1. Entrar a `https://git-scm.com/download/win` y bajar el instalador.
2. Instalar dejando todas las opciones como vienen (Next, Next, Install).
3. Abrir **PowerShell** (tecla Windows, escribir "PowerShell", Enter) y
   comprobar:

```powershell
git --version
```

Tiene que responder algo como `git version 2.x`. Después, decirle a Git tu
nombre (el **tuyo**: así tus cambios salen a tu nombre):

```powershell
git config --global user.name "Tu Nombre y Apellido"
git config --global user.email "el-mail-de-tu-cuenta-de-github"
```

## Paso 2. Instalar Flutter

1. Entrar a `https://docs.flutter.dev/get-started/install/windows/mobile`
   y bajar el **.zip de la versión estable** (stable).
2. Descomprimirlo en `C:\Users\TU_USUARIO\flutter`. **No** en
   `C:\Program Files` ni en una carpeta con espacios o acentos.
3. Agregar Flutter al **PATH** (para poder escribir `flutter` en cualquier
   carpeta):
   - Tecla Windows, escribir "variables de entorno" y abrir **"Editar las
     variables de entorno de esta cuenta"**.
   - En la lista de arriba, elegir **Path** y tocar **Editar**.
   - **Nuevo** y pegar `C:\Users\TU_USUARIO\flutter\bin`.
   - Aceptar todo.
4. **Cerrar PowerShell y abrir uno nuevo** (si no, no ve el cambio) y
   comprobar:

```powershell
flutter --version
```

Tiene que mostrar "Channel stable". La primera vez tarda un poco porque se
prepara solo.

## Paso 3. Instalar Android Studio

1. Entrar a `https://developer.android.com/studio` y bajar Android Studio.
2. Instalarlo con las opciones que vienen.
3. Al abrirlo por primera vez aparece el **Setup Wizard**: elegir
   **Standard** y aceptar. Descarga el Android SDK en
   `C:\Users\TU_USUARIO\AppData\Local\Android\Sdk`. Al final muestra
   "Android SDK is up to date": tocar **Finish**.

## Paso 4. Agregar las tres piezas que faltan del SDK

El asistente no instala todo lo que el proyecto necesita. Sin esto el APK
falla con "No Android SDK found" o "did not install NDK".

1. En la pantalla de bienvenida de Android Studio: **More Actions → SDK
   Manager** (con un proyecto abierto: **File → Settings → Languages &
   Frameworks → Android SDK**).
2. Ir a la pestaña **SDK Tools** y tildar, abajo a la derecha, **Show
   Package Details**.
3. Tildar:
   - **Android SDK Command-line Tools (latest)**.
   - **NDK (Side by side) → 28.2.13676358** (es la versión que pide el
     proyecto con Flutter 3.47; si al compilar el error nombra otro número,
     instalar ese).
   - **CMake →** la versión más nueva.
4. **Apply → OK** y esperar (el NDK pesa alrededor de 1 GB).

## Paso 5. Conectar Flutter con Android

En PowerShell:

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
flutter doctor --android-licenses
flutter doctor
```

- En las licencias, contestar `y` a todas.
- En `flutter doctor` lo que importa es **Android toolchain** con ✓. Si
  Visual Studio sale con ✗ no importa: solo sirve para apps de escritorio.

## Paso 6. Descargar el proyecto

**Con `git clone`, no con "Download ZIP"** (con el ZIP después no se puede
actualizar: da "not a git repository").

```powershell
cd $HOME\Documents
git clone https://github.com/ZogeGBR/ProgAppCelu.git
cd ProgAppCelu
git checkout main
git pull
flutter pub get
```

La rama con todo lo último es **`main`**.

## Paso 7. Comprobar que el proyecto anda

```powershell
flutter analyze
flutter test
```

| Comando | Resultado esperado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!` (158 pruebas) |

En `flutter test` aparecen algunos mensajes como "No se pudo anotar el
celular para los avisos": son pruebas que simulan errores **a propósito**.
Lo que vale es la última línea.

## Paso 8. Generar el APK

```powershell
flutter build apk --release
```

- **La primera vez tarda 10 a 20 minutos** (baja Gradle y las plataformas
  de Android que le falten). Aunque parezca trabado en "Running Gradle task
  'assembleRelease'...", dejarlo.
- Los `WARNING` de Java, de Kotlin en `firebase_core`, "deprecated API" y
  "source value 8 is obsolete" **no son errores**: vienen de paquetes de
  terceros.
- Termina con:

```
√ Built build\app\outputs\flutter-apk\app-release.apk (55.1MB)
```

Esa versión es el **modo demo**: todo simulado (pagos, repartidor, IA),
sin servidor y sin internet, con cuentas de prueba. Es la más segura para
presentar. La cámara, el GPS, el mapa y las notificaciones son reales.

## Paso 9. Preparar el celular

1. **Ajustes → Acerca del teléfono** → tocar **7 veces** "Número de
   compilación" (en Xiaomi: "Versión de MIUI/HyperOS"; en Samsung: Acerca
   del teléfono → Información de software). Aparece "Ya sos desarrollador".
2. **Ajustes → Sistema → Opciones de desarrollador** → activar
   **Depuración USB**. En Xiaomi activar también **"Instalar vía USB"**.
3. Conectar el celular a la PC con el cable. Si pregunta qué hacer con el
   USB, elegir **Transferencia de archivos**. Aceptar el cartel
   **"¿Permitir depuración USB?"** (tildar "Permitir siempre").

## Paso 10. Instalar la app

### Opción A: con el cable (recomendada)

```powershell
flutter devices
flutter install --release
```

`flutter devices` tiene que mostrar el celular (además de Windows y
Chrome). `flutter install` instala el APK que se generó en el paso 8.

### Opción B: sin cable

1. Mandarse `build\app\outputs\flutter-apk\app-release.apk` por WhatsApp,
   Drive o mail.
2. Abrirlo en el celular. Android pide permitir **"instalar apps de origen
   desconocido"** para WhatsApp/Drive/Archivos: aceptar.
3. Si aparece **Play Protect** ("app no reconocida"): **Más detalles →
   Instalar de todas formas**. Pasa porque no viene de Play Store.

## Paso 11. Probar y sacar las capturas (criterio F2)

Captura de pantalla en Android: **botón de encendido + bajar volumen** a la
vez. Cuentas de la demo (aparecen también en la pantalla de ingreso):

| Cuenta | Email | Contraseña |
|---|---|---|
| Dueño | `dueno@freshmarket.com` | `freshmarket` |
| Repartidor | `repartidor@freshmarket.com` | `freshmarket` |
| Recuperar contraseña | código | `123456` |

| N.º | Qué hacer | Qué tiene que pasar |
|---|---|---|
| 01 | Mirar el escritorio del celular y abrir la app | Ícono de FreshMarket y pantalla de arranque con el logo |
| 02 | Mantener apretado (o tocar) un producto | Se abre el detalle desde abajo, con "Agregar al carrito" |
| 03 | Carrito: deslizar un renglón hacia el costado | Se quita y aparece "Deshacer" |
| 04 | Pagar (marcar la casa en el mapa con "Usar mi ubicación") | El mapa se centra donde estás y escribe la calle |
| 05 | "Mi pedido" después de pagar | Mapa con la bici del repartidor moviéndose |
| 06 | Esperar unos segundos con la app minimizada | Notificación "Tu pedido está en camino"; al tocarla abre "Mi pedido" |
| 07 | "Mi pedido" → historial | Pedido anterior con **"Volver a pedir"** |
| 08 | Activar **modo avión** | Aviso "Sin internet" arriba |
| 09 | Girar el celular (acostado) | Nada se corta |
| 10 | Ingresar como dueño → "Mi almacén" → "Cargar producto con una foto" | Abre la cámara de verdad y la IA propone nombre y precio |
| 11 | Negar un permiso (ubicación o notificaciones) | La app no se cae y explica qué falta |
| 12 | Ajustes del celular → tamaño de letra al máximo | Todo se sigue leyendo |

Pasarle las capturas a Zoe (WhatsApp o Drive) con el número de la tabla
en el nombre (`04_gps.png`, etc.), o subirlas uno mismo:

```powershell
git pull
# copiar las capturas a docs\evidencias\
git add docs/evidencias
git commit -m "Capturas en celular real"
git push
```

(Para `git push` hace falta ser colaborador del repositorio; si da error de
permisos, pedirle a Zoe que te agregue en GitHub → Settings →
Collaborators.)

## Problemas frecuentes

| Mensaje | Qué hacer |
|---|---|
| `flutter : El término 'flutter' no se reconoce` | Falta el PATH (paso 2.3) o no se cerró y abrió PowerShell |
| `fatal: not a git repository` | Se bajó el ZIP. Clonar con `git clone` (paso 6) |
| `Your local changes ... would be overwritten by checkout` | `git stash`, después `git checkout main`, después `git stash pop` |
| `No Android SDK found` | Paso 5 (`flutter config --android-sdk ...`) |
| `Android sdkmanager did not install NDK 28.2.13676358` | Paso 4: instalar esa versión exacta del NDK |
| `Android license status unknown` | `flutter doctor --android-licenses` y `y` a todo |
| `Unable to locate a Java Runtime` | `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"` |
| El celular no aparece en `flutter devices` | Probar otro cable (que pase datos), elegir "Transferencia de archivos", volver a aceptar "Permitir depuración USB". En SDK Tools instalar **Google USB Driver** |
| "App no instalada" en el celular | Desinstalar la versión anterior de FreshMarket (estaba firmada con otra llave) y volver a instalar |
| "No queda espacio" al compilar | Liberar espacio y correr `flutter clean` antes de volver a compilar |
| La compilación parece trabada | La primera vez es normal que tarde hasta 20 minutos |

## Opcional

- **Con el servidor real** (pagos y avisos entre dos celulares en el mismo
  Wi-Fi): ver `docs/CELULAR_REAL.md`, opción B. Hace falta Node 22.13 o más
  nuevo y compilar con
  `flutter build apk --release --dart-define=URL_BACKEND=http://IP-DE-LA-PC:3000`.
- **Firma propia y App Bundle para Play Store:** ver `docs/PUBLICACION.md`.
  Para la presentación no hace falta: sin `android\key.properties` el APK se
  firma solo con la llave de prueba.

## ¿Y en iPhone?

No con este APK. Para iPhone hay que compilar **en una Mac con Xcode**;
desde Windows no se puede. Con una Mac y un Apple ID gratuito se instala por
cable en un iPhone, pero deja de abrir a los 7 días; para TestFlight o App
Store hace falta la cuenta de desarrollador de Apple (USD 99 por año). La
app ya está preparada para iOS (permisos con su motivo en `Info.plist`,
nombre, íconos y notificaciones en segundo plano); ver
`docs/PUBLICACION.md`, sección iOS.
