/// Qué respondió el celular al pedir el GPS.
///
/// Está en el dominio (y no en el servicio) porque lo usan los ViewModels
/// para mostrar mensajes, y un ViewModel no debe conocer la capa de
/// servicios.
enum PermisoUbicacion { concedido, denegado, gpsApagado }
