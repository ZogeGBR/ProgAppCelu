// Servicios falsos para las pruebas.
//
// Funcionan gracias a la inyección de dependencias: los repositorios
// reciben sus servicios por el constructor, así que acá se les pasa
// una versión que responde al instante y sin internet.
import 'dart:async';
import 'dart:typed_data';

import 'package:freshmarket_app/data/services/camara_service.dart';
import 'package:freshmarket_app/data/services/catalogo_service.dart';
import 'package:freshmarket_app/data/services/etiquetado_service.dart';
import 'package:freshmarket_app/data/services/geocodificacion_service.dart';
import 'package:freshmarket_app/data/services/api_client.dart';
import 'package:freshmarket_app/data/services/pago_service.dart';
import 'package:freshmarket_app/data/services/reparto_service.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
import 'package:freshmarket_app/data/services/sesion_service.dart';
import 'package:freshmarket_app/data/services/ubicacion_service.dart';
import 'package:freshmarket_app/domain/models/posicion.dart';
import 'package:freshmarket_app/domain/models/producto.dart';

const yerba = Producto(
  id: 'p2',
  nombre: 'Yerba mate 1kg',
  precio: 3800,
  categoria: 'Almacén',
);
const leche = Producto(
  id: 'p3',
  nombre: 'Leche entera 1L',
  precio: 1500,
  categoria: 'Lácteos',
);
const queso = Producto(
  id: 'p6',
  nombre: 'Queso cremoso (kg)',
  precio: 6500,
  categoria: 'Lácteos',
);

class CatalogoServiceFalso implements CatalogoService {
  CatalogoServiceFalso({this.fallasAntesDeResponder = 0});

  int fallasAntesDeResponder;
  int llamadas = 0;
  final guardados = <Map<String, dynamic>>[];
  final productos = [yerba.toJson(), leche.toJson(), queso.toJson()];

  @override
  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    llamadas++;
    if (fallasAntesDeResponder > 0) {
      fallasAntesDeResponder--;
      throw Exception('sin conexión');
    }
    return productos;
  }

  @override
  Future<Map<String, dynamic>> guardarProducto(
    Map<String, dynamic> datos,
  ) async {
    final nuevo = {...datos, 'id': 'nuevo-${guardados.length + 1}'};
    guardados.add(nuevo);
    return nuevo;
  }

  bool fallaAlGuardar = false;

  @override
  Future<Map<String, dynamic>> actualizarProducto(
    String id,
    Map<String, dynamic> cambios,
  ) async {
    if (fallaAlGuardar) throw Exception('sin conexión');
    final indice = productos.indexWhere((producto) => producto['id'] == id);
    productos[indice] = {...productos[indice], ...cambios};
    return productos[indice];
  }

  @override
  Future<void> eliminarProducto(String id) async {
    if (fallaAlGuardar) throw Exception('sin conexión');
    productos.removeWhere((producto) => producto['id'] == id);
  }
}

/// Dos cuentas: ceferino@x.com / clave-dueno y tobias@x.com / clave-reparto.
/// El código de recuperación correcto es 123456.
class SesionServiceFalso implements SesionService {
  bool sinConexion = false;
  final codigosPedidos = <String>[];
  final claves = <String, String>{
    'ceferino@x.com': 'clave-dueno',
    'tobias@x.com': 'clave-reparto',
  };

  @override
  Future<Map<String, dynamic>> ingresar(String email, String clave) async {
    if (sinConexion) throw Exception('sin conexión');
    if (claves[email] != clave) {
      throw const ApiException(401, 'Email o contraseña incorrectos.');
    }
    return email == 'ceferino@x.com'
        ? {'rol': 'dueno', 'token': 'token-dueno', 'nombre': 'Don Ceferino'}
        : {'rol': 'repartidor', 'token': 'token-reparto', 'nombre': 'Tobías'};
  }

  @override
  Future<void> solicitarCodigo(String email) async {
    if (sinConexion) throw Exception('sin conexión');
    codigosPedidos.add(email);
  }

  @override
  Future<void> confirmarCodigo({
    required String email,
    required String codigo,
    required String claveNueva,
  }) async {
    if (sinConexion) throw Exception('sin conexión');
    if (codigo != '123456' || !claves.containsKey(email)) {
      throw const ApiException(400, 'El código no es correcto.');
    }
    claves[email] = claveNueva;
  }
}

class RepartoServiceFalso implements RepartoService {
  bool falla = false;
  final posiciones = <Map<String, dynamic>>[];
  final entregados = <String>[];
  final pedidos = <Map<String, dynamic>>[
    {
      'id': 'r-1',
      'numero': 1005,
      'direccion': 'Belgrano 55',
      'destino': {'lat': -32.88, 'lng': -68.83},
      'total': 5300,
      'metodoPago': 'efectivo',
      'productos': ['1 × Yerba mate 1kg'],
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    if (falla) throw Exception('sin conexión');
    return List.of(pedidos);
  }

  @override
  Future<void> enviarPosicion(Map<String, dynamic> posicion) async {
    if (falla) throw Exception('sin señal');
    posiciones.add(posicion);
  }

  @override
  Future<void> marcarEntregado(String pedidoId) async {
    if (falla) throw Exception('sin señal');
    entregados.add(pedidoId);
    pedidos.removeWhere((pedido) => pedido['id'] == pedidoId);
  }
}

/// Las pruebas deciden el permiso y cuándo se mueve el repartidor.
class UbicacionFalsa implements UbicacionService {
  UbicacionFalsa({this.permiso = PermisoUbicacion.concedido});

  PermisoUbicacion permiso;
  Posicion? actual = const Posicion(latitud: -32.89, longitud: -68.84);
  final _controlador = StreamController<Posicion>.broadcast();

  void mover(Posicion posicion) => _controlador.add(posicion);

  bool get hayQuienEscuche => _controlador.hasListener;

  @override
  Future<PermisoUbicacion> pedirPermiso() async => permiso;

  @override
  Future<Posicion?> posicionActual() async =>
      permiso == PermisoUbicacion.concedido ? actual : null;

  @override
  Stream<Posicion> seguir() => _controlador.stream;
}

/// Responde "Calle <lat>" y cuenta cuántas veces le preguntaron. Con
/// [demoras] se puede hacer que una respuesta llegue más tarde que otra.
class GeocodificacionFalsa implements GeocodificacionService {
  int consultas = 0;
  bool falla = false;
  String? direccionFija;
  final demoras = <double, Duration>{};

  @override
  Future<Map<String, dynamic>> direccionDe(
    double latitud,
    double longitud,
  ) async {
    consultas++;
    final demora = demoras[latitud];
    if (demora != null) await Future<void>.delayed(demora);
    if (falla) throw Exception('sin conexión');
    return {'direccion': direccionFija ?? 'Calle $latitud'};
  }
}

/// Las pruebas deciden cuándo llega cada novedad del reparto.
class SeguimientoServiceFalso implements SeguimientoService {
  final _controlador = StreamController<Map<String, dynamic>>.broadcast();

  void emitir(Map<String, dynamic> novedad) => _controlador.add(novedad);

  void fallar() => _controlador.addError(Exception('sin señal'));

  @override
  Stream<Map<String, dynamic>> seguirPedido(
    String pedidoId, {
    Map<String, dynamic>? destino,
  }) {
    ultimoDestino = destino;
    return _controlador.stream;
  }

  Map<String, dynamic>? ultimoDestino;
}

class CamaraFalsa implements CamaraService {
  CamaraFalsa({this.foto});

  Uint8List? foto;

  @override
  Future<Uint8List?> tomarFoto({bool deGaleria = false}) async => foto;
}

class EtiquetadoServiceFalso implements EtiquetadoService {
  bool falla = false;

  @override
  Future<Map<String, dynamic>> analizarFoto(Uint8List foto) async {
    if (falla) throw Exception('la IA no respondió');
    return {
      'nombre': 'Aceite de girasol 1.5L',
      'categoria': 'Almacén',
      'precioSugerido': 3200,
      'emoji': '🫒',
    };
  }
}

/// Devuelve los estados de [respuestas] en orden (el último se repite).
class PagoServiceFalso implements PagoService {
  PagoServiceFalso({this.respuestas = const ['aprobado'], this.numero});

  /// El número que asignaría el servidor.
  final int? numero;

  final List<String> respuestas;
  bool fallaAlCrear = false;
  final pedidosEnviados = <Map<String, dynamic>>[];
  int _consultas = 0;

  @override
  Future<Map<String, dynamic>> crearPreferencia(
    Map<String, dynamic> pedido,
  ) async {
    if (fallaAlCrear) throw Exception('backend caído');
    pedidosEnviados.add(pedido);
    return {
      'preferenciaId': 'pref-1',
      'urlCheckout':
          pedido['metodoPago'] == 'efectivo' ? null : 'https://mp.test/pagar',
      'numero': numero,
    };
  }

  @override
  Future<Map<String, dynamic>> consultarEstado(String pedidoId) async {
    final indice =
        _consultas < respuestas.length ? _consultas : respuestas.length - 1;
    _consultas++;
    return {'estado': respuestas[indice]};
  }
}

class CheckoutFalso implements CheckoutLauncher {
  CheckoutFalso({this.seAbre = true});

  final bool seAbre;
  final abiertos = <Uri>[];

  @override
  Future<bool> abrir(Uri url) async {
    abiertos.add(url);
    return seAbre;
  }
}
