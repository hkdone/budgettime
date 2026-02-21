import 'package:intl/intl.dart';

String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    customPattern: '#,##0.00 ¤',
  );
  return formatter.format(amount);
}
