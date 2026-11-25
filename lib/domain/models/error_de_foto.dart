/// Algo falló DE VERDAD al usar la cámara o la galería (permiso negado,
/// no hay cámara...). Cancelar no es esto: cancelar devuelve null.
///
/// Vive en el dominio para que el ViewModel lo entienda sin conocer la
/// capa de datos: el servicio de cámara traduce el error de la plataforma
/// (`PlatformException`) a este error, con un mensaje para la persona.
class ErrorDeFoto implements Exception {
  const ErrorDeFoto(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ErrorDeFoto: $mensaje';
}
