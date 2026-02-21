import 'package:intl/intl.dart';

String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    customPattern: '#,##0.00 ¤',
  );
  return formatter.format(amount);
}

String formatDateForPb(DateTime date) {
  // PocketBase expects YYYY-MM-DD HH:MM:SS
  // We want to preserve the local calendar day, so we avoid UTC shifts that could change the day.
  // Standardizing on NOON to stay far from day boundaries.
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d 12:00:00';
}
