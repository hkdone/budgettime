import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
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
    DateTime nextDate = recurrence.nextDueDate.toLocal();

    // Safety check to avoid infinite loops
    const int maxIterations = 52; // Max 1 year of weekly for safety in one go
    int iterations = 0;

    while (nextDate.isBefore(periodEnd) && iterations < maxIterations) {
      if (recurrence.type == 'transfer' && recurrence.targetAccountId != null) {
        await _transactionRepo.addTransfer(
          sourceAccountId: recurrence.accountId,
          targetAccountId: recurrence.targetAccountId!,
          amount: recurrence.amount,
          date: nextDate,
          label: recurrence.label,
          category: 'Recurrence',
          recurrenceId: recurrence.id,
          status: 'projected',
          memberId: recurrence.memberId,
        );
      } else {
        final transactionData = {
          'amount': recurrence.amount,
          'label': recurrence.label,
          'type': recurrence.type,
          'date': formatDateForPb(nextDate),
          'account': recurrence.accountId,
          'member': recurrence.memberId,
          'status': 'projected',
          'category': 'Recurrence',
          'recurrence': recurrence.id,
          'is_automatic': true,
        };

        await _transactionRepo.addTransaction(transactionData);
      }

      // Calculate next date
      if (recurrence.frequency == 'weekly') {
        nextDate = nextDate.add(const Duration(days: 7));
      } else if (recurrence.frequency == 'biweekly') {
        nextDate = nextDate.add(const Duration(days: 14));
      } else if (recurrence.frequency == 'monthly') {
        // Move to next month and keep the same day
        final nextMonth = DateTime(nextDate.year, nextDate.month + 1, 1);
        final lastDayOfNextMonth = DateTime(
          nextDate.year,
          nextDate.month + 2,
          0,
        ).day;
        final targetDay = recurrence.dayOfMonth ?? recurrence.nextDueDate.day;
        nextDate = DateTime(
          nextMonth.year,
          nextMonth.month,
          targetDay > lastDayOfNextMonth ? lastDayOfNextMonth : targetDay,
        );
      } else if (recurrence.frequency == 'bimonthly') {
        final nextMonth = DateTime(nextDate.year, nextDate.month + 2, 1);
        final lastDayOfNextMonth = DateTime(
          nextDate.year,
          nextDate.month + 3,
          0,
        ).day;
        final targetDay = recurrence.dayOfMonth ?? recurrence.nextDueDate.day;
        nextDate = DateTime(
          nextMonth.year,
          nextMonth.month,
          targetDay > lastDayOfNextMonth ? lastDayOfNextMonth : targetDay,
        );
      } else if (recurrence.frequency == 'yearly') {
        nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
      } else if (recurrence.frequency == 'daily') {
        nextDate = nextDate.add(const Duration(days: 1));
      }

      iterations++;
    }
  }
}
