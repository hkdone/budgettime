/// Aperçu de rapprochement pour une ligne de boîte de réception.
class InboxMatchPreview {
  final String projectedLabel;
  final double projectedAmount;
  final double amountDelta;
  final int matchCount;

  const InboxMatchPreview({
    required this.projectedLabel,
    required this.projectedAmount,
    required this.amountDelta,
    required this.matchCount,
  });
}
