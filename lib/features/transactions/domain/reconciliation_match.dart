/// Résultat d'un rapprochement entre une opération réelle et une prévisionnelle.
class ReconciliationMatch {
  final Map<String, dynamic> transaction;
  final double score;
  final double amountDelta;
  final int daysDelta;
  final bool isVariableEnvelope;

  const ReconciliationMatch({
    required this.transaction,
    required this.score,
    required this.amountDelta,
    required this.daysDelta,
    required this.isVariableEnvelope,
  });

  String get transactionId => transaction['id'] as String;

  double get projectedAmount => (transaction['amount'] as num).abs().toDouble();

  String get label => transaction['label'] as String? ?? '';
}
