/// Formas de pago que ofrece FreshMarket, todas a través de Mercado Pago.
///
/// El nombre de cada valor viaja al backend tal cual (`metodo.name`),
/// que según eso limita los medios que muestra el checkout.
enum MetodoPago { debito, credito, billeteraMercadoPago }
