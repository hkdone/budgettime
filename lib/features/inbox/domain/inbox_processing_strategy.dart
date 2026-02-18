/// Interface for processing strategies
abstract class InboxProcessingStrategy {
  /// Returns a confidence score (0-1) if this strategy can handle the message
  double canHandle(Map<String, dynamic> item);

  /// Extract transaction data from the raw item.
  /// Returns null if extraction failed.
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item);
}
