/// Una línea de texto que se leyó en la foto del producto.
class LineaLeida {
  const LineaLeida({required this.texto, this.alto = 0, this.arriba = 0});

  final String texto;

  /// Alto de las letras en la foto: lo más grande suele ser el nombre.
  final double alto;

  /// Dónde empieza la línea desde arriba, para respetar el orden de lectura.
  final double arriba;
}

/// Arma la etiqueta de un producto con lo que se LEYÓ en su foto: el texto
/// del envase (marca, producto, cantidad) y lo que se ve en la imagen
/// ("Fruit", "Bottle"...). No inventa nada: si no se pudo leer el nombre,
/// lo deja vacío para que el dueño lo escriba. Nunca pone precio: el
/// precio lo decide el dueño.
///
/// Es Dart puro (sin cámara ni plugins) para poder probarlo en la PC.
abstract final class LectorDeEtiqueta {
  static const _maximoNombre = 60;
  static const _maximoDescripcion = 120;
  static const _lineasDelNombre = 2;
  static const _lineasPrincipales = 5;

  /// Devuelve `{'nombre', 'categoria', 'descripcion', 'emoji'}`, el mismo
  /// formato que manda el backend con la IA (sin `precioSugerido`).
  static Map<String, dynamic> armar({
    required List<LineaLeida> lineas,
    List<String> etiquetas = const [],
  }) {
    final utiles = [
      for (final linea in lineas)
        if (_esUtil(linea.texto)) linea,
    ];
    // Lo que está escrito más grande (el frente del envase) pesa más que
    // la letra chica: "leche" en los ingredientes de unas galletitas no
    // las vuelve un lácteo.
    final porTamano = [...utiles]..sort((a, b) => b.alto.compareTo(a.alto));
    final principal = _normalizar(
      porTamano.take(_lineasPrincipales).map((linea) => linea.texto),
    );
    final todoElTexto = _normalizar(lineas.map((linea) => linea.texto));
    final etiquetasEnMinuscula = [
      for (final etiqueta in etiquetas) etiqueta.toLowerCase(),
    ];

    // La cantidad ("1,5 L") suele estar sola en una línea: se busca en
    // todo lo leído, empezando por lo más grande (así no gana la porción
    // de la tabla nutricional).
    final todasPorTamano = [...lineas]
      ..sort((a, b) => b.alto.compareTo(a.alto));
    final cantidad = _cantidad(
      _normalizar(todasPorTamano.map((linea) => linea.texto)),
    );

    final nombre = _nombre(
      porTamano,
      cantidad,
      etiquetasEnMinuscula,
    );
    final categoria = _categoria(
      [principal, todoElTexto],
      etiquetasEnMinuscula,
      nombre,
    );
    return {
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': _descripcion(utiles, nombre),
      'emoji': _emoji(principal, etiquetasEnMinuscula, categoria),
    };
  }

  // ---------------------------------------------------------------- nombre

  static String _nombre(
    List<LineaLeida> porTamano,
    String? cantidad,
    List<String> etiquetas,
  ) {
    if (porTamano.isEmpty) return _nombreDesdeLaImagen(etiquetas);

    // Las líneas con letras más grandes, en el orden en que se leen.
    final elegidas = porTamano.take(_lineasDelNombre).toList()
      ..sort((a, b) => a.arriba.compareTo(b.arriba));
    var nombre = _enTitulo(elegidas.map((linea) => linea.texto).join(' '));

    if (cantidad != null && !_compacto(nombre).contains(_compacto(cantidad))) {
      nombre = '$nombre $cantidad';
    }
    return _recortar(nombre, _maximoNombre);
  }

  static String _nombreDesdeLaImagen(List<String> etiquetas) {
    for (final etiqueta in etiquetas) {
      final traducida = _traducciones[etiqueta];
      if (traducida != null) return traducida;
    }
    return '';
  }

  /// "1,5 L", "500 g", "900 ml"... si aparece en el envase.
  static String? _cantidad(String texto) {
    final encontrada = RegExp(
      r'(\d+(?:[.,]\d+)?)\s?(kg|grs|gr|g|ml|cc|lts|lt|litros|litro|l)\b',
    ).firstMatch(texto);
    if (encontrada == null) return null;
    final numero = encontrada.group(1)!.replaceAll('.', ',');
    final unidad = switch (encontrada.group(2)!) {
      'kg' => 'kg',
      'grs' || 'gr' || 'g' => 'g',
      'ml' || 'cc' => 'ml',
      _ => 'L',
    };
    return '$numero $unidad';
  }

  // ------------------------------------------------------------- categoría

  static String _categoria(
    List<String> textos,
    List<String> etiquetas,
    String nombre,
  ) {
    // Primero lo grande; si ahí no hay pistas, lo que reconoce la imagen;
    // recién después la letra chica.
    String? porPalabras(String texto) {
      for (final (categoria, palabras) in _palabrasPorCategoria) {
        if (palabras.any((palabra) => _contienePalabra(texto, palabra))) {
          return categoria;
        }
      }
      return null;
    }

    final porLoGrande = porPalabras(textos.first);
    if (porLoGrande != null) return porLoGrande;
    for (final (categoria, enIngles) in _etiquetasPorCategoria) {
      if (etiquetas.any(enIngles.contains)) return categoria;
    }
    for (final texto in textos.skip(1)) {
      final encontrada = porPalabras(texto);
      if (encontrada != null) return encontrada;
    }
    // Hay texto de envase pero ninguna pista: es un producto de almacén.
    return nombre.isEmpty ? 'Otros' : 'Almacén';
  }

  static const _palabrasPorCategoria = [
    (
      'Lácteos',
      [
        'leche', 'yogur', 'yogurt', 'queso', 'manteca', 'crema',
        'dulce de leche', 'ricota', 'postre lacteo',
      ],
    ),
    (
      'Bebidas',
      [
        'agua', 'gaseosa', 'cola', 'jugo', 'cerveza', 'vino', 'soda',
        'bebida', 'fernet', 'aperitivo', 'energizante', 'isotonica',
      ],
    ),
    (
      'Limpieza',
      [
        'detergente', 'lavandina', 'jabon', 'suavizante', 'limpiador',
        'desinfectante', 'lavavajilla', 'papel higienico', 'esponja',
        'cloro', 'shampoo', 'desodorante',
      ],
    ),
    (
      'Panadería',
      [
        'pan', 'galletita', 'galletitas', 'galleta', 'bizcocho', 'bizcochos',
        'tostadas', 'budin', 'facturas', 'grisines', 'pan rallado',
      ],
    ),
    (
      'Verdulería',
      [
        'banana', 'manzana', 'naranja', 'tomate', 'papa', 'cebolla',
        'lechuga', 'zanahoria', 'limon', 'palta',
      ],
    ),
    (
      'Almacén',
      [
        'aceite', 'arroz', 'fideos', 'harina', 'azucar', 'yerba', 'cafe',
        'sal', 'mermelada', 'pure', 'conserva', 'atun', 'lentejas',
        'galletas de arroz', 'mayonesa', 'ketchup', 'polenta', 'cacao',
      ],
    ),
  ];

  // Lo que reconoce el modelo de imágenes de ML Kit (en inglés).
  static const _etiquetasPorCategoria = [
    ('Verdulería', ['fruit', 'vegetable', 'produce', 'banana', 'apple']),
    ('Panadería', ['bread', 'baked goods', 'cookie', 'cake', 'pastry']),
    ('Lácteos', ['cheese', 'dairy', 'milk']),
    ('Bebidas', ['drink', 'juice', 'wine', 'beer', 'bottle', 'soft drink']),
    ('Almacén', ['food', 'pasta', 'rice', 'snack']),
  ];

  static const _traducciones = {
    'banana': 'Banana',
    'apple': 'Manzana',
    'fruit': 'Fruta',
    'vegetable': 'Verdura',
    'bread': 'Pan',
    'cookie': 'Galletitas',
    'cake': 'Torta',
    'cheese': 'Queso',
    'juice': 'Jugo',
    'wine': 'Vino',
    'beer': 'Cerveza',
    'pasta': 'Fideos',
    'rice': 'Arroz',
  };

  // ----------------------------------------------------- emoji y descripción

  static String _emoji(String texto, List<String> etiquetas, String categoria) {
    for (final (palabra, emoji) in _emojisPorPalabra) {
      if (_contienePalabra(texto, palabra) || etiquetas.contains(palabra)) {
        return emoji;
      }
    }
    return switch (categoria) {
      'Lácteos' => '🥛',
      'Bebidas' => '🥤',
      'Limpieza' => '🧴',
      'Panadería' => '🍞',
      'Verdulería' => '🥬',
      _ => '🛒',
    };
  }

  static const _emojisPorPalabra = [
    ('yerba', '🧉'),
    ('cafe', '☕'),
    ('aceite', '🫒'),
    ('arroz', '🍚'),
    ('fideos', '🍝'),
    ('queso', '🧀'),
    ('vino', '🍷'),
    ('cerveza', '🍺'),
    ('galletitas', '🍪'),
    ('banana', '🍌'),
    ('manzana', '🍎'),
    ('tomate', '🍅'),
  ];

  /// Otras líneas leídas (sabor, variedad), sin repetir el nombre.
  static String _descripcion(List<LineaLeida> utiles, String nombre) {
    final enElNombre = _sinAcentos(nombre.toLowerCase());
    final resto = [
      for (final linea in utiles)
        if (!enElNombre.contains(_sinAcentos(linea.texto.toLowerCase())))
          linea.texto.trim(),
    ];
    if (resto.isEmpty) return '';
    return _recortar(
      'Leído en el envase: ${resto.take(3).join(' · ')}',
      _maximoDescripcion,
    );
  }

  // ------------------------------------------------------------ utilidades

  /// Descarta lo que no sirve para nombrar el producto: códigos, tablas
  /// nutricionales, sitios web, leyendas legales.
  static bool _esUtil(String texto) {
    final limpio = texto.trim();
    if (limpio.length < 3) return false;
    final letras = RegExp('[A-Za-zÁÉÍÓÚÑáéíóúñ]').allMatches(limpio).length;
    if (letras < limpio.length / 2) return false;
    final minuscula = _sinAcentos(limpio.toLowerCase());
    return !_leyendas.any(minuscula.contains);
  }

  static const _leyendas = [
    'industria argentina', 'contenido neto', 'cont. neto', 'www', '@',
    'http', 'lote', 'vto', 'vence', 'ingredientes', 'informacion nutricional',
    'valor energetico', 'porcion', 'conservar', 'elaborado', 'rnpa', 'rne',
    'sin tacc', 'consumir', 'envasado', 'importado',
  ];

  static bool _contienePalabra(String texto, String palabra) =>
      RegExp('\\b${RegExp.escape(palabra)}\\b').hasMatch(texto);

  static String _enTitulo(String texto) {
    const chicas = {'de', 'del', 'la', 'el', 'y', 'con', 'sin', 'en', 'al'};
    final palabras = texto
        .split(RegExp(r'\s+'))
        .where((palabra) => palabra.isNotEmpty)
        .toList();
    return [
      for (var i = 0; i < palabras.length; i++)
        _capitalizar(
          palabras[i],
          esChica: i > 0 && chicas.contains(palabras[i].toLowerCase()),
        ),
    ].join(' ');
  }

  static String _capitalizar(String palabra, {required bool esChica}) {
    final minuscula = palabra.toLowerCase();
    if (esChica) return minuscula;
    // Cantidades y siglas ("1,5L", "UHT") quedan como están.
    if (RegExp(r'\d').hasMatch(palabra)) return palabra;
    return minuscula[0].toUpperCase() + minuscula.substring(1);
  }

  static String _recortar(String texto, int maximo) => texto.length <= maximo
      ? texto
      : '${texto.substring(0, maximo - 1).trimRight()}…';

  static String _normalizar(Iterable<String> textos) =>
      _sinAcentos(textos.join(' ').toLowerCase());

  /// Para comparar cantidades: "1.5 L" y "1,5l" son lo mismo.
  static String _compacto(String texto) =>
      texto.toLowerCase().replaceAll(' ', '').replaceAll('.', ',');

  static String _sinAcentos(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
}
