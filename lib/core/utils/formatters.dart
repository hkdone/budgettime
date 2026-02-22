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
  // We want to preserve the local calendar day, so we explicitly convert to Local
  // before extracting components.
  final local = date.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  // Standardizing on NOON to stay far from day boundaries even if another conversion happens.
  return '$y-$m-$d 12:00:00';
}
