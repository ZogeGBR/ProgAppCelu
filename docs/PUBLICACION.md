# Publicación (criterio F2)

Cómo pasar de "anda en mi celular" a "se puede instalar desde Play Store".
Lo de probar en un celular real (APK de demo y con backend) está en
[`CELULAR_REAL.md`](CELULAR_REAL.md).

## 1. Ícono y pantalla de arranque

Las imágenes están en `assets/icono/` y la configuración en `pubspec.yaml`.

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## 2. Versión

En `pubspec.yaml`: `version: 1.1.0+2`. El número después del `+` tiene que
**subir en cada versión** que se sube a Play Store.

## 3. Llave de firma (una sola vez)

Play Store exige que todas las versiones vengan firmadas con la misma
llave. Se crea así (Windows, desde `android/`):

```powershell
keytool -genkey -v -keystore freshmarket.jks -keyalg RSA -keysize 2048 -validity 10000 -alias freshmarket
```

Y se crea `android/key.properties` (**no se sube al repositorio**, ya está
en `.gitignore`):

```properties
storePassword=LA_CLAVE_QUE_ELEGISTE
keyPassword=LA_CLAVE_QUE_ELEGISTE
keyAlias=freshmarket
storeFile=../freshmarket.jks
```

> Guardar la llave y las claves en un lugar seguro (por ejemplo, el
> gestor de contraseñas del grupo). Si se pierden, no se puede actualizar
> la app en Play Store.

Sin `key.properties`, `build.gradle.kts` firma con la llave de debug: se
puede compilar igual, pero esa versión no sirve para Play Store.

## 4. Compilar

```bash
# Para pasar el archivo directo a un celular
flutter build apk --release

# Para Play Store (App Bundle)
flutter build appbundle --release --dart-define=URL_BACKEND=https://tu-backend
```

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

## 5. Prueba interna en Play Console

1. Crear la app en Play Console (cuenta de desarrollador).
2. **Prueba interna** → crear versión → subir el `.aab`.
3. Agregar los emails de quienes la prueban (el grupo y la profesora).
4. Completar lo que pide Google antes de publicar:
   - política de privacidad, porque la app usa cámara, ubicación y
     notificaciones;
   - clasificación de contenido;
   - "Seguridad de los datos": qué se guarda (dirección de entrega, email
     del dueño) y que viaja cifrado.
5. Compartir el link de prueba: se instala desde Play Store como cualquier
   app.

## 6. Checklist en el celular real

Marcar cada punto y sacar una captura (van al PDF de la presentación):

- [ ] Se instala y abre con el ícono y el splash nuevos.
- [ ] Catálogo: buscar, filtrar, mantener apretado → detalle.
- [ ] Carrito: deslizar para sacar y "Deshacer".
- [ ] Marcar la casa en el mapa: la dirección aparece sola; "Usar mi
      ubicación" pide permiso con el texto propio.
- [ ] Pagar con Mercado Pago (credenciales de prueba) y con efectivo.
- [ ] "Mi pedido": la bici se mueve en el mapa.
- [ ] Con la app cerrada llega "Tu pedido está en camino" y al tocarla abre
      "Mi pedido".
- [ ] Salir con el carrito lleno → a las 2 horas llega el recordatorio.
      Para la demo se puede bajar la espera en `RecordatoriosRepository`.
- [ ] Modo avión → aparece "Sin internet"; al volver, desaparece.
- [ ] "Volver a pedir" desde el historial.
- [ ] Dueño: cargar un producto con una foto, cambiar un precio.
- [ ] Repartidor: compartir el GPS y marcar "Entregado".
