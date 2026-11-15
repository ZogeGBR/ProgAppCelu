import 'package:flutter/material.dart';

import '../../../domain/models/metodo_pago.dart';

/// Textos e íconos de cada forma de pago (son de la vista, no del dominio).
extension MetodoPagoUi on MetodoPago {
  String get nombre => switch (this) {
        MetodoPago.debito => 'Tarjeta de débito',
        MetodoPago.credito => 'Tarjeta de crédito',
        MetodoPago.billeteraMercadoPago => 'Dinero en Mercado Pago',
        MetodoPago.efectivo => 'Efectivo al recibir',
      };

  String get ayuda => switch (this) {
        MetodoPago.debito => 'Se descuenta de tu cuenta del banco.',
        MetodoPago.credito => 'Se paga en tu próximo resumen.',
        MetodoPago.billeteraMercadoPago =>
          'Usás la plata que tenés en la app de Mercado Pago.',
        MetodoPago.efectivo => 'Le pagás al repartidor cuando llega.',
      };

  IconData get icono => switch (this) {
        MetodoPago.debito => Icons.credit_card,
        MetodoPago.credito => Icons.credit_score,
        MetodoPago.billeteraMercadoPago => Icons.account_balance_wallet,
        MetodoPago.efectivo => Icons.payments_outlined,
      };
}
