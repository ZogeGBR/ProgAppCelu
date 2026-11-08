import 'package:flutter_test/flutter_test.dart';
import 'package:freshmarket_app/data/repositories/notificaciones_repository.dart';
import 'package:freshmarket_app/data/repositories/pago_repository.dart';
import 'package:freshmarket_app/data/repositories/reparto_repository.dart';
import 'package:freshmarket_app/data/repositories/sesion_repository.dart';
import 'package:freshmarket_app/data/services/push_service.dart';
import 'package:freshmarket_app/data/services/seguimiento_service.dart';
import 'package:freshmarket_app/domain/models/aviso.dart';
import 'package:freshmarket_app/domain/models/metodo_pago.dart';
import 'package:freshmarket_app/ui/avisos/view_models/avisos_view_model.dart';
import 'package:freshmarket_app/ui/carrito/view_models/carrito_view_model.dart';
import 'package:freshmarket_app/ui/inicio/view_models/navegacion_view_model.dart';
import 'package:freshmarket_app/ui/pago/view_models/pago_view_model.dart';
import 'package:freshmarket_app/ui/reparto/view_models/reparto_view_model.dart';

import 'fakes.dart';

/// Notificaciones: el modelo, el repositorio que une push + notificación
/// local + backend, y los ViewModels que las observan.
void main() {
  const enCamino = Aviso(
    titulo: 'Tu pedido #1001 está en camino',
    cuerpo: 'El repartidor ya salió.',
    pedidoId: 'p-1',
  );
  const nuevoPedido = Aviso(
    titulo: 'Nuevo pedido #1002',
    cuerpo: r'$7.600 · Belgrano 55',
    tipo: TipoAviso.nuevoPedido,
    pedidoId: 'p-2',
  );

  group('Aviso', () {
    test('lo que llega de Firebase se entiende (datos + título y texto)', () {
      final aviso = Aviso.desdeDatos(
        {'tipo': 'nuevoPedido', 'pedidoId': 'p-9'},
        titulo: 'Nuevo pedido #1009',
        cuerpo: 'Belgrano 55',
      );
      expect(aviso.tipo, TipoAviso.nuevoPedido);
      expect(aviso.pedidoId, 'p-9');
      expect(aviso.titulo, 'Nuevo pedido #1009');
    });

    test('un tipo que la app no conoce se trata como aviso del pedido', () {
      final aviso = Aviso.desdeDatos({'tipo': 'promocion'});
      expect(aviso.tipo, TipoAviso.pedido);
      expect(aviso.titulo, 'FreshMarket');
    });

    test('viaja como texto en la notificación local y vuelve igual', () {
      final vuelta = Aviso.desdeTexto(nuevoPedido.aTexto());
      expect(vuelta?.titulo, nuevoPedido.titulo);
      expect(vuelta?.cuerpo, nuevoPedido.cuerpo);
      expect(vuelta?.tipo, nuevoPedido.tipo);
      expect(vuelta?.pedidoId, nuevoPedido.pedidoId);
    });

    test('un texto roto o vacío no rompe nada', () {
      expect(Aviso.desdeTexto('no es json'), isNull);
      expect(Aviso.desdeTexto(''), isNull);
      expect(Aviso.desdeTexto(null), isNull);
    });

    test('dos avisos del mismo pedido usan la misma notificación', () {
      const llego = Aviso(titulo: 'Llegó', cuerpo: '', pedidoId: 'p-1');
      expect(llego.idNotificacion, enCamino.idNotificacion);
      expect(nuevoPedido.idNotificacion, isNot(enCamino.idNotificacion));
      expect(enCamino.idNotificacion, greaterThanOrEqualTo(0));
    });
  });

  group('NotificacionesRepository', () {
    late PushFalso push;
    late NotificacionLocalFalsa local;
    late AvisosServiceFalso servidor;
    late NotificacionesRepository repositorio;

    setUp(() {
      push = PushFalso();
      local = NotificacionLocalFalsa();
      servidor = AvisosServiceFalso();
      repositorio = NotificacionesRepository(
        push: push,
        local: local,
        servidor: servidor,
      );
    });

    tearDown(() => repositorio.dispose());

    test('al iniciar crea el canal y pide el permiso una vez', () async {
      await repositorio.iniciar();
      await repositorio.iniciar(); // Llamarlo de nuevo no repite nada.

      expect(local.iniciada, isTrue);
      expect(local.pedidosDePermiso, 1);
      expect(repositorio.permisoConcedido, isTrue);
    });

    test('un push con la app abierta se muestra y se publica', () async {
      final publicados = <Aviso>[];
      repositorio.recibidos.listen(publicados.add);
      await repositorio.iniciar();

      push.enviar(enCamino);
      await Future<void>.delayed(Duration.zero);

      expect(local.mostradas.single.titulo, enCamino.titulo);
      expect(publicados.single.pedidoId, 'p-1');
    });

    test('tocar el push o la notificación local llega por el mismo stream',
        () async {
      final tocados = <Aviso>[];
      repositorio.tocados.listen(tocados.add);
      await repositorio.iniciar();

      push.tocar(enCamino);
      local.tocar(nuevoPedido);

      expect(tocados.map((a) => a.tipo), [
        TipoAviso.pedido,
        TipoAviso.nuevoPedido,
      ]);
    });

    test('el token se le pide a Firebase una sola vez', () async {
      final pedido = CarritoViewModel().armarPedido(MetodoPago.efectivo);
      await repositorio.seguirPedido(pedido);
      await repositorio.anotarCuenta();
      await repositorio.olvidarCuenta();

      expect(push.pedidosDeToken, 1);
      expect(servidor.pedidos, [pedido.id]);
      expect(servidor.cuentas, ['token-de-prueba-1']);
      expect(servidor.olvidadas, ['token-de-prueba-1']);
    });

    test('sin token (sin Google Play) no se anota y reintenta después',
        () async {
      push.token = null;
      final pedido = CarritoViewModel().armarPedido(MetodoPago.efectivo);
      await repositorio.seguirPedido(pedido);
      expect(servidor.pedidos, isEmpty);

      push.token = 'token-que-llego-tarde';
      await repositorio.seguirPedido(pedido);
      expect(servidor.pedidos, [pedido.id]);
      expect(push.pedidosDeToken, 2);
    });

    test('si la persona no da permiso, se sabe y se puede volver a pedir',
        () async {
      local.concedePermiso = false;
      await repositorio.iniciar();
      expect(repositorio.permisoConcedido, isFalse);

      local.concedePermiso = true;
      expect(await repositorio.pedirPermiso(), isTrue);
      expect(repositorio.permisoConcedido, isTrue);
    });
  });

  group('AvisosViewModel', () {
    late PushFalso push;
    late NotificacionLocalFalsa local;
    late AvisosServiceFalso servidor;
    late NotificacionesRepository notificaciones;
    late PagoRepository pagos;
    late SesionRepository sesion;
    late AvisosViewModel viewModel;

    setUp(() {
      push = PushFalso();
      local = NotificacionLocalFalsa();
      servidor = AvisosServiceFalso();
      notificaciones = NotificacionesRepository(
        push: push,
        local: local,
        servidor: servidor,
      );
      pagos = PagoRepository(
        service: PagoServiceFalso(),
        checkout: CheckoutFalso(),
      );
      sesion = SesionRepository(service: SesionServiceFalso());
      viewModel = AvisosViewModel(
        repositorio: notificaciones,
        pagos: pagos,
        sesion: sesion,
      );
    });

    tearDown(() => viewModel.dispose());

    Future<void> pagarEnEfectivo() async {
      final carrito = CarritoViewModel()..agregarProducto(yerba);
      final pago = PagoViewModel(
        repositorio: pagos,
        armarPedido: carrito.armarPedido,
      )
        ..elegirMetodo(MetodoPago.efectivo)
        ..cambiarDireccion('Belgrano 55');
      await pago.pagar();
      pago.dispose();
      await Future<void>.delayed(Duration.zero);
    }

    test('al confirmarse un pedido, el celular se anota para sus avisos',
        () async {
      await pagarEnEfectivo();
      expect(servidor.pedidos, hasLength(1));
    });

    test('al entrar el dueño se anota y al salir se borra', () async {
      await sesion.ingresar('ceferino@x.com', 'clave-dueno');
      await Future<void>.delayed(Duration.zero);
      expect(servidor.cuentas, hasLength(1));

      sesion.salir();
      await Future<void>.delayed(Duration.zero);
      expect(servidor.olvidadas, hasLength(1));
    });

    test('sin conexión con el backend, la compra sigue igual', () async {
      servidor.falla = true;
      await pagarEnEfectivo();
      expect(servidor.pedidos, isEmpty); // No se rompió nada.
    });

    test('el cartel de "Activá las notificaciones" sale solo si se negó',
        () async {
      expect(viewModel.permisoDenegado, isFalse, reason: 'no se preguntó');

      local.concedePermiso = false;
      await viewModel.iniciar();
      expect(viewModel.permisoDenegado, isTrue);

      local.concedePermiso = true;
      await viewModel.pedirPermiso();
      expect(viewModel.permisoDenegado, isFalse);
    });

    test('si la notificación local falla al iniciar, la app sigue', () async {
      final rota = NotificacionesRepository(
        push: push,
        local: _NotificacionLocalRota(),
        servidor: servidor,
      );
      final otro = AvisosViewModel(repositorio: rota);
      addTearDown(otro.dispose);

      await otro.iniciar(); // No tira error.
      expect(otro.permisoDenegado, isTrue);
    });
  });

  group('quién observa los avisos', () {
    late PushFalso push;
    late NotificacionesRepository notificaciones;
    late SesionRepository sesion;

    setUp(() async {
      push = PushFalso();
      notificaciones = NotificacionesRepository(
        push: push,
        local: NotificacionLocalFalsa(),
        servidor: AvisosServiceFalso(),
      );
      sesion = SesionRepository(service: SesionServiceFalso());
      await notificaciones.iniciar();
    });

    test('tocar "tu pedido está en camino" abre "Mi pedido"', () {
      final navegacion = NavegacionViewModel(
        sesion: sesion,
        notificaciones: notificaciones,
      );
      addTearDown(navegacion.dispose);

      push.tocar(enCamino);

      expect(navegacion.actual, Seccion.miPedido);
    });

    test('tocar "nuevo pedido" abre la sección de quien está', () async {
      final navegacion = NavegacionViewModel(
        sesion: sesion,
        notificaciones: notificaciones,
      );
      addTearDown(navegacion.dispose);

      await sesion.ingresar('tobias@x.com', 'clave-reparto');
      navegacion.irA(Seccion.comprar);
      push.tocar(nuevoPedido);
      expect(navegacion.actual, Seccion.repartir);

      sesion.salir();
      navegacion.irA(Seccion.carrito);
      push.tocar(nuevoPedido);
      expect(navegacion.actual, Seccion.comprar, reason: 'ya no hay sesión');
    });

    test('al repartidor le aparece el pedido nuevo sin tocar nada', () async {
      final service = RepartoServiceFalso();
      final reparto = RepartoViewModel(
        repositorio: RepartoRepository(
          service: service,
          ubicacion: UbicacionFalsa(),
        ),
        sesion: sesion,
        notificaciones: notificaciones,
      );
      addTearDown(reparto.dispose);
      await sesion.ingresar('tobias@x.com', 'clave-reparto');
      await Future<void>.delayed(Duration.zero);
      final consultasAntes = service.consultas;

      push.enviar(nuevoPedido);
      await Future<void>.delayed(Duration.zero);

      expect(service.consultas, consultasAntes + 1);
    });

    test('un cliente (sin sesión) no recarga el reparto por un aviso',
        () async {
      final service = RepartoServiceFalso();
      final reparto = RepartoViewModel(
        repositorio: RepartoRepository(
          service: service,
          ubicacion: UbicacionFalsa(),
        ),
        sesion: sesion,
        notificaciones: notificaciones,
      );
      addTearDown(reparto.dispose);

      push.enviar(nuevoPedido);
      await Future<void>.delayed(Duration.zero);

      expect(service.consultas, 0);
    });
  });

  test('en la demo, el servidor simulado avisa al salir y al llegar (2 veces)',
      () async {
    final push = PushServiceSimulado();
    final avisos = <Aviso>[];
    push.recibidos.listen(avisos.add);
    const service = SeguimientoServiceSimulado(
      intervalo: Duration(milliseconds: 1),
      pasosEnCamino: 4,
    );
    final conPush = SeguimientoServiceSimulado(
      intervalo: service.intervalo,
      pasosEnCamino: service.pasosEnCamino,
      push: push,
    );

    await conPush.seguirPedido('p-1').toList();
    await Future<void>.delayed(Duration.zero);

    expect(avisos.map((a) => a.titulo), [
      'Tu pedido está en camino',
      'Tu pedido llegó',
    ]);
    expect(avisos.every((a) => a.pedidoId == 'p-1'), isTrue);
  });
}

class _NotificacionLocalRota extends NotificacionLocalFalsa {
  @override
  Future<void> iniciar() async => throw Exception('sin plugin');
}
