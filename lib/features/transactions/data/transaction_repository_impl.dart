import '../../../core/services/database_service.dart';
import '../domain/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseService _dbService;

  TransactionRepositoryImpl(this._dbService);

  @override
  Future<List<Map<String, dynamic>>> getTransactions({
    required DateTime start,
    required DateTime end,
    String? accountId,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    // Format dates for PocketBase filter (YYYY-MM-DD HH:MM:SS)
    final startStr = start.toUtc().toString().split('.')[0];
    final endStr = end.toUtc().toString().split('.')[0];

    String filter =
        'user = "${user.id}" && date >= "$startStr" && date <= "$endStr"';

    if (accountId != null) {
      filter += ' && account = "$accountId"';
    }

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          sort: '-date',
          expand:
              'account,recurrence', // Expand account to get details if needed
        );

    return records.map((e) => e.toJson()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getOverdueProjectedTransactions({
    required DateTime beforeDate,
    String? accountId,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    // Format date for PocketBase filter (YYYY-MM-DD HH:MM:SS)
    // We want strictly LESS THAN start date.
    final dateStr = beforeDate.toUtc().toString().split('.')[0];

    String filter =
        'user = "${user.id}" && status = "projected" && date < "$dateStr"';

    if (accountId != null) {
      filter += ' && account = "$accountId"';
    }

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          sort:
              '-date', // Most recent overdue first? Or oldest? Maybe oldest on top to clear them? Let's stick to -date consistent with main list
          expand: 'account,recurrence',
        );

    return records.map((e) => e.toJson()).toList();
  }

  @override
  Future<double> getBalance({
    String? accountId,
    String? status,
    DateTime? maxDate,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return 0.0;

    String filter = 'user = "${user.id}"';
    if (accountId != null) {
      filter += ' && account = "$accountId"';
    }
    if (status != null) {
      filter += ' && status = "$status"';
    }
    if (maxDate != null) {
      final dateStr = maxDate.toUtc().toString().split('.')[0];
      filter += ' && date <= "$dateStr"';
    }

    // Optimized fetch: only get amount and type
    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(filter: filter, fields: 'amount,type');

    double total = 0.0;
    for (final r in records) {
      final amount = (r.data['amount'] as num).toDouble();
      final type = r.data['type'];
      if (type == 'income') {
        total += amount;
      } else {
        total -= amount;
      }
    }
    return total;
  }

  @override
  Future<void> addTransaction(Map<String, dynamic> data) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    // Ensure status is set (default to 'effective' if not provided)
    if (!data.containsKey('status')) {
      data['status'] = 'effective';
    }

    await _dbService.pb
        .collection('transactions')
        .create(body: {'user': user.id, ...data});
  }

  @override
  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    await _dbService.pb.collection('transactions').update(id, body: data);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _dbService.pb.collection('transactions').delete(id);
  }

  @override
  Future<void> deleteFutureTransactions(
    String recurrenceId,
    DateTime fromDate,
  ) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    final dateStr = fromDate.toUtc().toIso8601String();

    // Find all projected transactions for this recurrence after the date
    // 1. Delete Future Projected Transactions
    try {
      final validRecords = await _dbService.pb
          .collection('transactions')
          .getFullList(
            filter:
                'user = "${user.id}" && recurrence = "$recurrenceId" && status = "projected" && date >= "$dateStr"',
          );

      for (final record in validRecords) {
        await _dbService.pb.collection('transactions').delete(record.id);
      }
    } catch (e) {
      // print('Error deleting future transactions: $e');
    }

    // 2. CRITICAL: Stop the recurrence (Set active = false)
    // This must happen regardless of whether transactions were found/deleted.
    try {
      await _dbService.pb
          .collection('recurrences')
          .update(recurrenceId, body: {'active': false});
    } catch (e) {
      // print('Error stopping recurrence: $e');
    }
  }

  @override
  Future<void> updateFutureTransactions(
    String recurrenceId,
    DateTime fromDate,
    Map<String, dynamic> data,
  ) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    final dateStr = fromDate.toUtc().toIso8601String();

    // Find all projected transactions for this recurrence after the date
    final validRecords = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter:
              'user = "${user.id}" && recurrence = "$recurrenceId" && status = "projected" && date >= "$dateStr"',
        );

    for (final record in validRecords) {
      // We only update fields that are relevant for the projection (amount, label, category, etc.)
      // Be careful not to overwrite the Date if not intended, but usually 'data' comes from the edited transaction
      // which might have a specific date.
      // Ideally, we only update Amount, Label, Category, Account. NOT Date.

      final updateData = Map<String, dynamic>.from(data);
      updateData.remove(
        'date',
      ); // Don't shift dates of future projections based on one edit
      updateData.remove('id');
      updateData.remove('created');
      updateData.remove('updated');

      await _dbService.pb
          .collection('transactions')
          .update(record.id, body: updateData);
    }
  }
}
