import 'package:flutter_riverpod/flutter_riverpod.dart';

// Since the file structure might be slightly different in the prompt vs reality,
// I'll adjust imports. Assuming standard structure:
// lib/features/recurrences/presentation/recurrence_controller.dart

import '../domain/recurrence.dart';
import '../data/recurrence_repository_impl.dart';
import '../application/recurrence_service.dart';
import '../../../core/start_app.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class RecurrenceController extends StateNotifier<AsyncValue<List<Recurrence>>> {
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
    state = await AsyncValue.guard(() => _repository.getRecurrences());
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
        'next_due_date': nextDueDate.toUtc().toString().split('.')[0],
        'day_of_month': dayOfMonth,
        'active': true,
        'target_account': targetAccountId,
      });

      if (createdRecurrence != null) {
        // Generate projections for the next year
        final now = DateTime.now();
        final periodEnd = now.add(const Duration(days: 365));

        await _recurrenceService.generateProjectedTransactions(
          recurrence: createdRecurrence!,
          periodEnd: periodEnd,
        );

        // Notify dashboard
        _ref.read(dashboardControllerProvider.notifier).refresh();
      }

      return _repository.getRecurrences();
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
        'next_due_date': nextDueDate.toUtc().toString(),
        'day_of_month': dayOfMonth,
        'target_account': targetAccountId,
      });

      final updatedRecurrences = await _repository.getRecurrences();
      final updated = updatedRecurrences.firstWhere((r) => r.id == id);

      // 3. Regenerate projections
      final now = DateTime.now();
      final periodEnd = now.add(const Duration(days: 365));

      await _recurrenceService.generateProjectedTransactions(
        recurrence: updated,
        periodEnd: periodEnd,
      );

      // Notify dashboard
      _ref.read(dashboardControllerProvider.notifier).refresh();

      return updatedRecurrences;
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

      return _repository.getRecurrences();
    });
  }
}

final recurrenceControllerProvider =
    StateNotifierProvider<RecurrenceController, AsyncValue<List<Recurrence>>>((
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
