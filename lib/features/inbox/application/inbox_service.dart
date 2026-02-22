import '../../transactions/domain/transaction_repository.dart';
import '../domain/inbox_repository.dart';
import '../domain/inbox_processing_strategy.dart';
import '../domain/strategies/default_regex_strategy.dart';
import '../domain/strategies/la_banque_postale_strategy.dart';
import '../domain/strategies/credit_mutuel_strategy.dart';

class InboxService {
  final InboxRepository _inboxRepo;
  final TransactionRepository _transactionRepo;
  final List<InboxProcessingStrategy> _strategies;

  InboxService(this._inboxRepo, this._transactionRepo)
    : _strategies = [
        DefaultRegexStrategy(),
        LaBanquePostaleSmsParser(),
        LaBanquePostaleAppParser(),
        CreditMutuelSmsParser(),
      ];

  /// Returns suggested transaction data for an item
  Map<String, dynamic>? previewItem(Map<String, dynamic> item) {
    InboxProcessingStrategy? bestStrategy;
    double maxScore = 0.0;

    for (final strategy in _strategies) {
      final score = strategy.canHandle(item);
      if (score > maxScore) {
        maxScore = score;
        bestStrategy = strategy;
      }
    }

    if (bestStrategy != null && maxScore > 0.3) {
      return bestStrategy.extractTransactionData(item);
    }
    return null;
  }

  Future<int> processPendingItems() async {
    final items = await _inboxRepo.getUnprocessedItems();
    int processedCount = 0;

    for (final item in items) {
      final transactionData = previewItem(item);
      if (transactionData != null) {
        try {
          // Create transaction in database
          await _transactionRepo.addTransaction(transactionData);

          // Mark raw item as processed
          await _inboxRepo.markAsProcessed(item['id']);
          processedCount++;
        } catch (e) {
          await _inboxRepo.markAsError(item['id'], e.toString());
        }
      }
    }

    return processedCount;
  }
}
