/// Origine d'une transaction pour le calcul de solde (ancre bancaire).
abstract final class TransactionOrigin {
  static const manual = 'manual';
  static const bank = 'bank';
  static const anchor = 'anchor';

  static const bankSyncLabel = 'Ajustement solde (Banque)';
}
