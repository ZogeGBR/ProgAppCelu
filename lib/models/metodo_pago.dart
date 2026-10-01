import 'package:flutter/material.dart';

/// Formas de pago que pidió Don Ceferino: "con tarjeta o Mercado Pago".
enum MetodoPago { tarjeta, mercadoPago }

extension MetodoPagoInfo on MetodoPago {
  String get nombre {
    switch (this) {
      case MetodoPago.tarjeta:
        return 'Tarjeta';
      case MetodoPago.mercadoPago:
        return 'Mercado Pago';
    }
  }

  IconData get icono {
    switch (this) {
      case MetodoPago.tarjeta:
        return Icons.credit_card;
      case MetodoPago.mercadoPago:
        return Icons.account_balance_wallet;
    }
  }
}
