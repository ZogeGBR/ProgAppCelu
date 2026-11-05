/// Quién está usando la app, además de los clientes (que compran sin cuenta).
enum Rol { dueno, repartidor }

/// La sesión del dueño o del repartidor, después de ingresar con su clave.
class Sesion {
  const Sesion({required this.rol, required this.token});

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
        rol: Rol.values.byName(json['rol'] as String),
        token: json['token'] as String,
      );

  final Rol rol;
  final String token;
}
