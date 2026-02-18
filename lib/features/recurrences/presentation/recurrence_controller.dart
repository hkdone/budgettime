import 'package:flutter_riverpod/flutter_riverpod.dart';

// Since the file structure might be slightly different in the prompt vs reality,
// I'll adjust imports. Assuming standard structure:
// lib/features/recurrences/presentation/recurrence_controller.dart

import '../domain/recurrence.dart';
import '../data/recurrence_repository_impl.dart';

class RecurrenceController extends StateNotifier<AsyncValue<List<Recurrence>>> {
  final RecurrenceRepositoryImpl _repository;

  RecurrenceController(this._repository) : super(const AsyncValue.loading()) {
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
        'next_due_date': nextDueDate.toUtc().toString(),
        'day_of_month': dayOfMonth,
        'active': true,
      });
      return _repository.getRecurrences();
    });
    return createdRecurrence;
  }

  Future<void> deleteRecurrence(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteRecurrence(id);
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
      return RecurrenceController(repository);
    });
