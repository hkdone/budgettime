import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../domain/recurrence.dart';

import '../../../core/start_app.dart';

final recurrenceServiceProvider = Provider<RecurrenceService>((ref) {
  return RecurrenceService(ref.read(transactionRepositoryProvider));
});

class RecurrenceService {
  final TransactionRepository _transactionRepo;

  RecurrenceService(this._transactionRepo);

  /// Generates projected transactions for a recurrence within a specific period.
  Future<void> generateProjectedTransactions({
    required Recurrence recurrence,
    required DateTime periodEnd,
  }) async {
    DateTime nextDate = recurrence.nextDueDate;

    // Safety check to avoid infinite loops
    const int maxIterations = 52; // Max 1 year of weekly for safety in one go
    int iterations = 0;

    while (nextDate.isBefore(periodEnd) && iterations < maxIterations) {
      final transactionData = {
        'amount': recurrence.amount,
        'label': recurrence.label,
        'type': recurrence.type,
        'date': nextDate.toUtc().toIso8601String(),
        'account': recurrence.accountId,
        'status': 'projected',
        'category': 'Recurrence', // Or fetch from recurrence if added
        'recurrence': recurrence.id, // Link to recurrence if possible
        'is_automatic': true,
      };

      await _transactionRepo.addTransaction(transactionData);

      // Calculate next date
      if (recurrence.frequency == 'weekly') {
        nextDate = nextDate.add(const Duration(days: 7));
      } else if (recurrence.frequency == 'monthly') {
        // Handle month overflow logic if needed, simplify for now
        nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
      } else if (recurrence.frequency == 'yearly') {
        nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
      } else if (recurrence.frequency == 'daily') {
        nextDate = nextDate.add(const Duration(days: 1));
      }

      iterations++;
    }
  }
}
