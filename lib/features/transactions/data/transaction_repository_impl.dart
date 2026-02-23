import '../../../core/services/database_service.dart';
import '../../../core/utils/formatters.dart';
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

    // Use full day range for filtering
    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} 00:00:00';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} 23:59:59';

    String filter =
        'user = "${user.id}" && date >= "$startStr" && date <= "$endStr"';

    if (accountId != null) {
      filter += ' && (account = "$accountId" || target_account = "$accountId")';
    }

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          sort: '-date',
          expand: 'account,target_account,recurrence,member,category',
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

    // We want strictly LESS THAN start date (exclusive of the start day)
    final dateStr =
        '${beforeDate.year}-${beforeDate.month.toString().padLeft(2, '0')}-${beforeDate.day.toString().padLeft(2, '0')} 00:00:00';

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
          expand: 'account,recurrence,member,category',
        );

    return records.map((e) => e.toJson()).toList();
  }

  @override
  Future<double> getBalance({
    String? accountId,
    String? status,
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return 0.0;

    String filter = 'user = "${user.id}"';
    if (status != null) {
      filter += ' && status = "$status"';
    }

    // If accountId is provided, we must check both account AND target_account
    // to catch incoming transfers.
    if (accountId != null) {
      filter += ' && (account = "$accountId" || target_account = "$accountId")';
    }

    if (minDate != null) {
      final dateStr =
          '${minDate.year}-${minDate.month.toString().padLeft(2, '0')}-${minDate.day.toString().padLeft(2, '0')} 00:00:00';
      filter += ' && date >= "$dateStr"';
    }
    if (maxDate != null) {
      final dateStr =
          '${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}-${maxDate.day.toString().padLeft(2, '0')} 23:59:59';
      filter += ' && date <= "$dateStr"';
    }

    // Optimized fetch: get amount, type, date and bank_balance for anchor logic
    // We fetch ALL records and sort by date DESC to find the latest anchor.
    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          fields:
              'id,amount,type,date,bank_balance,status,account,target_account',
          sort: '-date,-created', // Latest first, tie-break with creation time
        );

    // 1. Find the latest anchor (first record with bank_balance since sorted DESC)
    Map<String, dynamic>? latestAnchorData;
    DateTime? anchorDate;
    String? latestAnchorId;

    for (final r in records) {
      if (r.data['bank_balance'] != null) {
        latestAnchorData = r.data;
        latestAnchorId = r.id;
        anchorDate = DateTime.parse(r.data['date']);
        break; // Found the latest
      }
    }

    double total = 0.0;

    if (latestAnchorData != null && anchorDate != null) {
      // Start from the anchor balance
      total = (latestAnchorData['bank_balance'] as num).toDouble();

      // We only count:
      // - Effective transactions STRICTLY AFTER the anchor day
      // - Projected transactions ALWAYS counted if they are after the anchor day

      // Define "Anchor Day" for comparison
      final anchorDay = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
      );

      for (final r in records) {
        if (r.id == latestAnchorId) continue; // Already counted

        final d = DateTime.parse(r.data['date']);
        final currentDay = DateTime(d.year, d.month, d.day);

        final isAfterAnchor = currentDay.isAfter(anchorDay);
        final isProjected = r.data['status'] == 'projected';

        // Anchor logic: ignore effective on same day or before.
        if (isAfterAnchor || isProjected) {
          final amount = (r.data['amount'] as num).toDouble();

          final String? tAccount = r.data['account'];
          final String? tTargetAccount = r.data['target_account'];

          // Transfer logic
          if (tTargetAccount != null && tTargetAccount.isNotEmpty) {
            if (accountId == null) {
              // Global balance: transfers are neutral
              continue;
            } else if (tAccount == accountId) {
              // Money leaving this account
              total -= amount;
            } else if (tTargetAccount == accountId) {
              // Money entering this account
              total += amount;
            }
          } else {
            // Standard transaction
            final type = r.data['type'];
            if (type == 'income') {
              total += amount;
            } else {
              total -= amount;
            }
          }
        }
      }
    } else {
      // No anchor, use standard sum
      for (final r in records) {
        final amount = (r.data['amount'] as num).toDouble();

        final String? tAccount = r.data['account'];
        final String? tTargetAccount = r.data['target_account'];

        if (tTargetAccount != null && tTargetAccount.isNotEmpty) {
          if (accountId == null) {
            // Global balance neutral
            continue;
          } else if (tAccount == accountId) {
            total -= amount;
          } else if (tTargetAccount == accountId) {
            total += amount;
          }
        } else {
          final type = r.data['type'];
          if (type == 'income') {
            total += amount;
          } else {
            total -= amount;
          }
        }
      }
    }

    return total;
  }

  @override
  Future<void> addTransaction(Map<String, dynamic> data) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    // Ensure status is set (default to 'effective' if not provided)
    if (data['date'] is DateTime) {
      data['date'] = formatDateForPb(data['date'] as DateTime);
    }

    if (!data.containsKey('status')) {
      data['status'] = 'effective';
    }

    await _dbService.pb
        .collection('transactions')
        .create(body: {'user': user.id, ...data});
  }

  @override
  Future<void> addTransfer({
    required String sourceAccountId,
    required String targetAccountId,
    required double amount,
    required DateTime date,
    required String label,
    String? category,
    String? recurrenceId,
    String? status,
    String? memberId,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    final dateStr = formatDateForPb(date);
    final effectiveStatus = status ?? 'effective';

    try {
      // Unify transfer into a single transaction record.
      // My balance logic already handles bidirectional transfers.
      await _dbService.pb
          .collection('transactions')
          .create(
            body: {
              'user': user.id,
              'account': sourceAccountId,
              'target_account': targetAccountId,
              'amount': amount,
              'label': label,
              'type': 'expense', // Standardized as expense from source account
              'date': dateStr,
              'status': effectiveStatus,
              'category': category ?? 'transfer',
              'recurrence': recurrenceId,
              'member': memberId,
              'is_automatic': false,
            },
          );
    } catch (e) {
      // ignore: avoid_print
      print('ERROR in addTransfer: $e');
      try {
        final dynamic err = e;
        if (err.response != null) {
          // ignore: avoid_print
          print('PocketBase Error Details: ${err.response}');
        }
      } catch (_) {}
      rethrow;
    }
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

    final dateStr = formatDateForPb(fromDate);

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

    final dateStr = formatDateForPb(fromDate);

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
