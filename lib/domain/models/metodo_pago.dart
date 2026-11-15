/// Formas de pago que ofrece FreshMarket. Todas pasan por Mercado Pago,
/// menos [efectivo], que se le paga al repartidor al recibir.
///
/// El nombre de cada valor viaja al backend tal cual (`metodo.name`),
/// que según eso limita los medios que muestra el checkout.
enum MetodoPago { debito, credito, billeteraMercadoPago, efectivo }
