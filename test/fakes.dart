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
import 'package:freshmarket_app/data/services/pago_service.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
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
}

/// Las pruebas deciden cuándo llega cada novedad del reparto.
class SeguimientoServiceFalso implements SeguimientoService {
  final _controlador = StreamController<Map<String, dynamic>>.broadcast();

  void emitir(Map<String, dynamic> novedad) => _controlador.add(novedad);

  void fallar() => _controlador.addError(Exception('sin señal'));

  @override
  Stream<Map<String, dynamic>> seguirPedido(String pedidoId) =>
      _controlador.stream;
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
  PagoServiceFalso({this.respuestas = const ['aprobado']});

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
    return {'preferenciaId': 'pref-1', 'urlCheckout': 'https://mp.test/pagar'};
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
