import 'package:flutter_riverpod/flutter_riverpod.dart';

// Since the file structure might be slightly different in the prompt vs reality,
// I'll adjust imports. Assuming standard structure:
// lib/features/recurrences/presentation/recurrence_controller.dart

import '../domain/recurrence.dart';
import '../data/recurrence_repository_impl.dart';
import '../application/recurrence_service.dart';
import '../../../core/start_app.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class RecurrenceState {
  final List<Recurrence> recurrences;
  final Map<String, int> projectionsCount;

  RecurrenceState({
    this.recurrences = const [],
    this.projectionsCount = const {},
  });
}

class RecurrenceController extends StateNotifier<AsyncValue<RecurrenceState>> {
  final RecurrenceRepositoryImpl _repository;
  final TransactionRepository _transactionRepo;
  final RecurrenceService _recurrenceService;
  final Ref _ref;

  RecurrenceController(
    this._repository,
    this._transactionRepo,
    this._recurrenceService,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    getRecurrences();
  }

  Future<void> getRecurrences() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final recurrences = await _repository.getRecurrences();
      final counts = await _transactionRepo.getRecurrenceProjectionsCount();

      // Check for automatic recharge
      bool needsRefresh = false;
      for (final r in recurrences) {
        if (r.active) {
          final count = counts[r.id] ?? 0;
          if (count <= 2) {
            // Auto recharge for 1 year
            final now = DateTime.now();
            final periodEnd = DateTime(now.year + 1, 12, 31);
            await _recurrenceService.generateProjectedTransactions(
              recurrence: r,
              periodEnd: periodEnd,
            );
            needsRefresh = true;
          }
        }
      }

      if (needsRefresh) {
        // Refresh counts after auto-recharge
        final newCounts = await _transactionRepo
            .getRecurrenceProjectionsCount();
        return RecurrenceState(
          recurrences: recurrences,
          projectionsCount: newCounts,
        );
      }

      return RecurrenceState(
        recurrences: recurrences,
        projectionsCount: counts,
      );
    });
  }

  Future<Recurrence?> addRecurrence(
    String accountId,
    double amount,
    String label,
    String type,
    String frequency,
    DateTime nextDueDate, {
    int? dayOfMonth,
    String? targetAccountId,
    String? categoryId,
    String? memberId,
  }) async {
    state = const AsyncValue.loading();
    Recurrence? createdRecurrence;
    state = await AsyncValue.guard(() async {
      createdRecurrence = await _repository.addRecurrence({
        'account': accountId,
        'amount': amount,
        'label': label,
        'type': type,
        'frequency': frequency,
        'next_due_date': formatDateForPb(nextDueDate),
        'day_of_month': dayOfMonth,
        'active': true,
        'target_account': targetAccountId,
        'category': categoryId,
        'member': memberId,
      });

      if (createdRecurrence != null) {
        // Generate projections for the next year
        final now = DateTime.now();
        final periodEnd = DateTime(now.year + 1, 12, 31);

        await _recurrenceService.generateProjectedTransactions(
          recurrence: createdRecurrence!,
          periodEnd: periodEnd,
        );

        // Notify dashboard
        _ref.read(dashboardControllerProvider.notifier).refresh();
      }

      final recurrences = await _repository.getRecurrences();
      final counts = await _transactionRepo.getRecurrenceProjectionsCount();
      return RecurrenceState(
        recurrences: recurrences,
        projectionsCount: counts,
      );
    });
    return createdRecurrence;
  }

  Future<void> updateRecurrence(
    String id, {
    required String accountId,
    required double amount,
    required String label,
    required String type,
    required String frequency,
    required DateTime nextDueDate,
    int? dayOfMonth,
    String? targetAccountId,
    String? categoryId,
    String? memberId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Delete future projections first
      await _transactionRepo.deleteFutureTransactions(id, DateTime.now());

      // 2. Update recurrence
      await _repository.updateRecurrence(id, {
        'account': accountId,
        'amount': amount,
        'label': label,
        'type': type,
        'frequency': frequency,
        'next_due_date': formatDateForPb(nextDueDate),
        'day_of_month': dayOfMonth,
        'target_account': targetAccountId,
        'category': categoryId,
        'member': memberId,
        'active': true,
      });

      final updatedRecurrences = await _repository.getRecurrences();
      final updated = updatedRecurrences.firstWhere((r) => r.id == id);

      // 3. Regenerate projections
      // 3. Regenerate projections until end of next year
      final now = DateTime.now();
      final periodEnd = DateTime(now.year + 1, 12, 31);

      await _recurrenceService.generateProjectedTransactions(
        recurrence: updated,
        periodEnd: periodEnd,
      );

      // Notify dashboard
      _ref.read(dashboardControllerProvider.notifier).refresh();

      final counts = await _transactionRepo.getRecurrenceProjectionsCount();
      return RecurrenceState(
        recurrences: updatedRecurrences,
        projectionsCount: counts,
      );
    });
  }

  Future<void> deleteRecurrence(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Delete future projections
      await _transactionRepo.deleteFutureTransactions(id, DateTime.now());

      // 2. Delete recurrence
      await _repository.deleteRecurrence(id);

      // Notify dashboard
      _ref.read(dashboardControllerProvider.notifier).refresh();

      final recurrences = await _repository.getRecurrences();
      final counts = await _transactionRepo.getRecurrenceProjectionsCount();
      return RecurrenceState(
        recurrences: recurrences,
        projectionsCount: counts,
      );
    });
  }

  /// Extends projections for a recurrence
  Future<void> rechargeRecurrence(Recurrence recurrence) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      // Period end: end of current year + 1 (ensure at least 12-24 months)
      // To get ~11 recurrences back if monthly, we need to go at least 1 year ahead
      final periodEnd = DateTime(now.year + 1, 12, 31);

      await _recurrenceService.generateProjectedTransactions(
        recurrence: recurrence,
        periodEnd: periodEnd,
      );

      final recurrences = await _repository.getRecurrences();
      final counts = await _transactionRepo.getRecurrenceProjectionsCount();
      return RecurrenceState(
        recurrences: recurrences,
        projectionsCount: counts,
      );
    });
  }
}

final recurrenceControllerProvider =
    StateNotifierProvider<RecurrenceController, AsyncValue<RecurrenceState>>((
      ref,
    ) {
      final repository =
          ref.watch(recurrenceRepositoryProvider) as RecurrenceRepositoryImpl;
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final recurrenceService = ref.watch(recurrenceServiceProvider);

      return RecurrenceController(
        repository,
        transactionRepo,
        recurrenceService,
        ref,
      );
    });
