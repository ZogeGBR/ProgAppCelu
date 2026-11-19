# Reglas de R8 (achica el código del APK release).
#
# El plugin de ML Kit que lee el texto de la foto menciona los modelos de
# chino, devanagari, japonés y coreano, pero no los incluye: solo usamos el
# alfabeto latino. Sin estas líneas R8 los busca, no los encuentra y la
# compilación falla ("minifyReleaseWithR8 ... Compilation failed").
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit también trae una función para bajar modelos desde Firebase (que no
# usamos: los modelos vienen dentro de la app). Esa función menciona
# FirebaseInstanceId, de la librería vieja firebase-iid que se excluye en
# build.gradle.kts para que no choque con firebase-messaging. Como ese
# código nunca se ejecuta, R8 no tiene que buscar esa clase.
-dontwarn com.google.firebase.iid.**
