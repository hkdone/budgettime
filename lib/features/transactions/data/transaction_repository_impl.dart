import '../../../core/services/database_service.dart';
import '../../../core/utils/formatters.dart';
import '../domain/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseService _dbService;

  TransactionRepositoryImpl(this._dbService);

  @override
  Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? accountId,
  }) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    String filter = 'user = "${user.id}"';

    if (start != null && end != null) {
      // Use full day range for filtering
      final startStr =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} 00:00:00';
      final endStr =
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} 23:59:59';
      filter += ' && date >= "$startStr" && date <= "$endStr"';
    }

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

    return records.map((e) {
      final json = e.toJson();
      final Map<String, dynamic> expandMap = {};

      const expandKeys = [
        'account',
        'target_account',
        'recurrence',
        'member',
        'category',
      ];
      for (final key in expandKeys) {
        try {
          final expanded = e.get<List<dynamic>>('expand.$key');
          if (expanded.isNotEmpty) {
            // Unify: If there is only one item, we can take it directly
            // This simplifies access in the UI/Controllers
            expandMap[key] = expanded[0].toJson();
          }
        } catch (_) {}
      }

      if (expandMap.isNotEmpty) {
        json['expand'] = expandMap;
      }
      return json;
    }).toList();
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
      filter += ' && (account = "$accountId" || target_account = "$accountId")';
    }

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          sort: '-date',
          expand: 'account,recurrence,member,category',
        );

    return records.map((e) {
      final json = e.toJson();
      final Map<String, dynamic> expandMap = {};
      const expandKeys = ['account', 'recurrence', 'member', 'category'];

      for (final key in expandKeys) {
        try {
          final expanded = e.get<List<dynamic>>('expand.$key');
          if (expanded.isNotEmpty) {
            expandMap[key] = expanded[0].toJson();
          }
        } catch (_) {}
      }

      if (expandMap.isNotEmpty) {
        json['expand'] = expandMap;
      }
      return json;
    }).toList();
  }

  @override
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

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: filter,
          fields:
              'id,amount,type,date,bank_balance,status,account,target_account,created,is_automatic',
          sort: '-date,-created',
        );

    // Grouping items by account to process them independently (Anchor per account logic)
    final Map<String, List<Map<String, dynamic>>> accountGroups = {};
    for (final r in records) {
      final data = r.toJson();
      final accId = data['account'] as String?;
      if (accId != null) {
        accountGroups.putIfAbsent(accId, () => []).add(data);
      }
      final targetId = data['target_account'] as String?;
      if (targetId != null && targetId.isNotEmpty) {
        accountGroups.putIfAbsent(targetId, () => []).add(data);
      }
    }

    double grandTotal = 0.0;
    // If accountId is specified, only calculate for that one.
    // Otherwise, calculate for all accounts that have transactions in the result.
    final targetAccountIds = accountId != null
        ? [accountId]
        : accountGroups.keys.toList();

    for (final targetAccId in targetAccountIds) {
      final group = accountGroups[targetAccId] ?? [];

      // 1. Find the latest anchor (bank_balance) for THIS account
      Map<String, dynamic>? anchor;
      for (final r in group) {
        // An anchor MUST be an automatic bank balance update FOR THIS account
        if (r['bank_balance'] != null &&
            r['account'] == targetAccId &&
            (r['is_automatic'] == true || r['is_automatic'] == 1)) {
          anchor = r;
          break;
        }
      }

      double accTotal = 0.0;
      DateTime? anchorDate;
      DateTime? anchorCreated;

      if (anchor != null) {
        accTotal = (anchor['bank_balance'] as num).toDouble();
        anchorDate = DateTime.parse(anchor['date']);
        anchorCreated = DateTime.parse(anchor['created']);
      }

      // 2. Sum up all other records relative to the anchor
      for (final r in group) {
        if (anchor != null && r['id'] == anchor['id']) continue;

        final rStatus = r['status'];
        final rDate = DateTime.parse(r['date']);
        final rCreated = DateTime.parse(r['created']);
        final isProjected = rStatus == 'projected';

        bool shouldCount = false;
        if (isProjected) {
          // Projected items are always counted (they represent missing money from bank balance)
          shouldCount = true;
        } else if (anchor != null) {
          // Effective items: only count if after anchor
          if (rDate.isAfter(anchorDate!)) {
            shouldCount = true;
          } else if (rDate.isAtSameMomentAs(anchorDate)) {
            // Created AFTER the anchor on the same day? Then it's not in the bank balance yet.
            if (rCreated.isAfter(anchorCreated!)) {
              shouldCount = true;
            }
          }
        } else {
          // No anchor ever: sum everything effective
          shouldCount = true;
        }

        if (shouldCount) {
          final amount = (r['amount'] as num).toDouble();
          final String? tSource = r['account'];
          final String? tTarget = r['target_account'];

          if (tTarget != null && tTarget.isNotEmpty) {
            // Bidirectional Transfer
            if (tSource == targetAccId) {
              accTotal -= amount;
            } else if (tTarget == targetAccId) {
              accTotal += amount;
            }
          } else {
            // Standard Transaction
            if (r['type'] == 'income') {
              accTotal += amount;
            } else {
              accTotal -= amount;
            }
          }
        }
      }
      grandTotal += accTotal;
    }

    return grandTotal;
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

  @override
  Future<Map<String, int>> getRecurrenceProjectionsCount() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return {};

    final records = await _dbService.pb
        .collection('transactions')
        .getFullList(
          filter: 'user = "${user.id}" && status = "projected"',
          fields: 'recurrence',
        );

    final Map<String, int> counts = {};
    for (final r in records) {
      final String recurrenceId = r.getStringValue('recurrence');
      if (recurrenceId.isNotEmpty) {
        counts[recurrenceId] = (counts[recurrenceId] ?? 0) + 1;
      }
    }
    return counts;
  }
}
