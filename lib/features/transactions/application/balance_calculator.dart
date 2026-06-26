import '../domain/transaction_origin.dart';

/// Calcule le solde effectif à partir d'une liste de transactions d'un compte.
abstract final class BalanceCalculator {
  static String resolveOrigin(Map<String, dynamic> record) {
    final explicit = record['origin'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final hasBankBalance = record['bank_balance'] != null;
    final isAutomatic =
        record['is_automatic'] == true || record['is_automatic'] == 1;
    if (hasBankBalance && isAutomatic) return TransactionOrigin.anchor;

    return TransactionOrigin.manual;
  }

  static bool isBankSyncAnchor(Map<String, dynamic> record) {
    if (resolveOrigin(record) != TransactionOrigin.anchor) return false;
    final label = record['label'] as String? ?? '';
    return label.contains('Banque');
  }

  /// [records] triées par `-date,-created` (plus récent en premier).
  static double computeForAccount(
    List<Map<String, dynamic>> records,
    String accountId,
  ) {
    Map<String, dynamic>? latestAnchor;
    Map<String, dynamic>? latestBankSyncAnchor;

    for (final r in records) {
      if (r['account'] != accountId) continue;
      if (r['bank_balance'] == null) continue;
      if (r['is_automatic'] != true && r['is_automatic'] != 1) continue;

      latestAnchor ??= r;
      if (isBankSyncAnchor(r)) {
        latestBankSyncAnchor ??= r;
      }
    }

    double accTotal = 0.0;
    DateTime? anchorDate;
    DateTime? anchorCreated;

    if (latestAnchor != null) {
      accTotal = (latestAnchor['bank_balance'] as num).toDouble();
      anchorDate = DateTime.parse(latestAnchor['date'] as String);
      anchorCreated = DateTime.parse(latestAnchor['created'] as String);
    }

    final hasBankSyncAnchor = latestBankSyncAnchor != null;

    for (final r in records) {
      if (latestAnchor != null && r['id'] == latestAnchor['id']) continue;

      final origin = resolveOrigin(r);
      if (origin == TransactionOrigin.anchor) continue;

      final rStatus = r['status'];
      final rDate = DateTime.parse(r['date'] as String);
      final rCreated = DateTime.parse(r['created'] as String);
      final isProjected = rStatus == 'projected';

      bool shouldCount = false;

      if (isProjected) {
        shouldCount = true;
      } else if (origin == TransactionOrigin.bank && hasBankSyncAnchor) {
        // Déjà reflété dans l'ancre bancaire Enable Banking.
        shouldCount = false;
      } else if (latestAnchor != null) {
        if (rDate.isAfter(anchorDate!)) {
          shouldCount = true;
        } else if (_sameCalendarDay(rDate, anchorDate)) {
          if (rCreated.isAfter(anchorCreated!)) {
            shouldCount = true;
          }
        }
      } else {
        shouldCount = true;
      }

      if (!shouldCount) continue;

      final amount = (r['amount'] as num).toDouble();
      final String? tSource = r['account'] as String?;
      final String? tTarget = r['target_account'] as String?;

      if (tTarget != null && tTarget.isNotEmpty) {
        if (tSource == accountId) {
          accTotal -= amount;
        } else if (tTarget == accountId) {
          accTotal += amount;
        }
      } else if (r['account'] == accountId) {
        if (r['type'] == 'income') {
          accTotal += amount;
        } else {
          accTotal -= amount;
        }
      }
    }

    return accTotal;
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
