import '../../transactions/domain/transaction_repository.dart';
import '../domain/inbox_repository.dart';
import '../domain/inbox_processing_strategy.dart';
import '../domain/strategies/default_regex_strategy.dart';

class InboxService {
  final InboxRepository _inboxRepo;
  final TransactionRepository _transactionRepo;
  final List<InboxProcessingStrategy> _strategies;

  InboxService(this._inboxRepo, this._transactionRepo)
    : _strategies = [
        DefaultRegexStrategy(),
        // Add other strategies here
      ];

  Future<int> processPendingItems() async {
    final items = await _inboxRepo.getUnprocessedItems();
    int processedCount = 0;

    for (final item in items) {
      InboxProcessingStrategy? bestStrategy;
      double maxScore = 0.0;

      // Find best strategy
      for (final strategy in _strategies) {
        final score = strategy.canHandle(item);
        if (score > maxScore) {
          maxScore = score;
          bestStrategy = strategy;
        }
      }

      if (bestStrategy != null && maxScore > 0.5) {
        try {
          final transactionData = bestStrategy.extractTransactionData(item);
          if (transactionData != null) {
            // Create transaction in database
            await _transactionRepo.addTransaction(transactionData);

            // Mark raw item as processed
            await _inboxRepo.markAsProcessed(item['id']);
            processedCount++;
          } else {
            await _inboxRepo.markAsError(
              item['id'],
              'Extraction failed despite match',
            );
          }
        } catch (e) {
          await _inboxRepo.markAsError(item['id'], e.toString());
        }
      } else {
        // No strategy found, maybe mark as ignored/error or leave for manual check
        // For now, leave it.
      }
    }

    return processedCount;
  }
}
