import 'package:flutter/material.dart';
import 'providers/carrito_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AppRoot());
}

/// Widget raíz de la app.
///
/// Es Stateful (aunque no dibuje nada distinto en pantalla) porque
/// necesitamos que el CarritoProvider se cree UNA sola vez y
/// persista durante toda la vida de la app. Si lo creáramos dentro
/// de un StatelessWidget, se perdería cada vez que Flutter
/// reconstruye el árbol (los widgets son inmutables, el State no).
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  // Se crea una sola vez, en initState, antes del primer build().
  late final CarritoProvider _carrito;

  @override
  void initState() {
    super.initState();
    _carrito = CarritoProvider();
  }

  @override
  void dispose() {
    _carrito.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32), // verde, "buena onda"
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'FreshMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      // El carrito se pasa por constructor de pantalla en pantalla
      // (prop drilling), tal como lo venimos viendo en clase con el
      // patrón de callbacks, sin usar ningún paquete externo de
      // manejo de estado.
      home: HomeScreen(carrito: _carrito),
    );
  }
}
