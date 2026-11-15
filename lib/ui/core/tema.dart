import 'package:flutter/material.dart';

/// Color principal de FreshMarket (verde almacén).
const colorMarca = Color(0xFF2E7D32);

/// Alto mínimo de los botones: más grande que el estándar (48) para
/// que sea fácil tocarlos sin errar.
const altoBotonGrande = 56.0;

/// Tema de la app pensado para personas que no usan mucho el celular:
/// letra más grande, botones altos y buen contraste.
ThemeData crearTema() {
  final colores = ColorScheme.fromSeed(seedColor: colorMarca);
  final base = ThemeData(colorScheme: colores, useMaterial3: true);
  // Ojo: Size.fromHeight daría ancho infinito y rompería los botones
  // que están dentro de un Row.
  const tamanoBoton = Size(64, altoBotonGrande);
  const textoBoton = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  final bordeBoton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return base.copyWith(
    scaffoldBackgroundColor: colores.surfaceContainerLowest,
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 19),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colores.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colores.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colores.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colores.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: tamanoBoton,
        textStyle: textoBoton,
        shape: bordeBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: tamanoBoton,
        textStyle: textoBoton,
        shape: bordeBoton,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
