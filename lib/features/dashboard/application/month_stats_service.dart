import '../../transactions/domain/categories.dart';
import '../presentation/widgets/statistics_widgets.dart';

/// Agrégation mensuelle partagée (dashboard + stats).
class PeriodAccountStats {
  double realIncome = 0;
  double realExpense = 0;
  double projectedIncome = 0;
  double projectedExpense = 0;
  final Map<String, double> realExpenseByCategory = {};
  final Map<String, double> projectedExpenseByCategory = {};
  final Map<String, double> realIncomeByCategory = {};
  final Map<String, double> projectedIncomeByCategory = {};
  final Map<String, double> realExpenseByMember = {};
  final Map<String, double> projectedExpenseByMember = {};
  final Map<String, double> realIncomeByMember = {};
  final Map<String, double> projectedIncomeByMember = {};

  double get projectedDelta => projectedIncome - projectedExpense;

  List<CategoryStats> expenseStats({required bool realOnly}) {
    final map = realOnly ? realExpenseByCategory : projectedExpenseByCategory;
    final total = realOnly ? realExpense : projectedExpense;
    return _toCategoryStats(map, total);
  }

  List<CategoryStats> incomeStats({required bool realOnly}) {
    final map = realOnly ? realIncomeByCategory : projectedIncomeByCategory;
    final total = realOnly ? realIncome : projectedIncome;
    return _toCategoryStats(map, total);
  }

  List<MemberStats> expenseStatsByMember({required bool realOnly}) {
    final map = realOnly ? realExpenseByMember : projectedExpenseByMember;
    final total = realOnly ? realExpense : projectedExpense;
    return _toMemberStats(map, total);
  }

  List<MemberStats> incomeStatsByMember({required bool realOnly}) {
    final map = realOnly ? realIncomeByMember : projectedIncomeByMember;
    final total = realOnly ? realIncome : projectedIncome;
    return _toMemberStats(map, total);
  }

  List<CategoryStats> _toCategoryStats(Map<String, double> map, double total) {
    if (total <= 0) return [];
    final list = map.entries
        .map(
          (e) => CategoryStats(
            categoryId: MonthStatsService.normalizeCategoryId(e.key),
            amount: e.value,
            percentage: (e.value / total) * 100,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<MemberStats> _toMemberStats(Map<String, double> map, double total) {
    if (total <= 0) return [];
    final list = map.entries
        .map(
          (e) => MemberStats(
            memberId: e.key,
            amount: e.value,
            percentage: (e.value / total) * 100,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

}

class MonthStatsService {
  const MonthStatsService._();

  static String normalizeCategoryId(String id) {
    if (id == 'unknown' || id == 'Recurrence') return 'other';
    return id;
  }

  static PeriodAccountStats computeForAccount({
    required List<dynamic> transactions,
    required String accountId,
  }) {
    final stats = PeriodAccountStats();

    for (final t in transactions) {
      if (t['is_automatic'] == true) continue;
      final label = t['label']?.toString().toLowerCase() ?? '';
      if (label.contains('solde') || label.contains('ajustement')) continue;

      final isTransfer =
          t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty;

      String role = 'none';
      if (isTransfer) {
        if (t['target_account'] == accountId) {
          role = 'income';
        } else if (t['account'] == accountId) {
          role = 'expense';
        }
      } else if (t['account'] == accountId) {
        role = t['type'] == 'income' ? 'income' : 'expense';
      }

      if (role == 'none') continue;

      final amount = (t['amount'] as num).toDouble();
      final isReal = (t['status'] ?? 'effective') == 'effective';
      final categoryId = MonthStatsService.normalizeCategoryId(
        t['category']?.toString() ?? 'other',
      );
      final memberId = t['member']?.toString() ?? 'common';

      if (role == 'income') {
        if (isTransfer) continue;
        stats.projectedIncome += amount;
        stats.projectedIncomeByCategory[categoryId] =
            (stats.projectedIncomeByCategory[categoryId] ?? 0) + amount;
        stats.projectedIncomeByMember[memberId] =
            (stats.projectedIncomeByMember[memberId] ?? 0) + amount;
        if (isReal) {
          stats.realIncome += amount;
          stats.realIncomeByCategory[categoryId] =
              (stats.realIncomeByCategory[categoryId] ?? 0) + amount;
          stats.realIncomeByMember[memberId] =
              (stats.realIncomeByMember[memberId] ?? 0) + amount;
        }
      } else {
        if (isTransfer) continue;
        stats.projectedExpense += amount;
        stats.projectedExpenseByCategory[categoryId] =
            (stats.projectedExpenseByCategory[categoryId] ?? 0) + amount;
        stats.projectedExpenseByMember[memberId] =
            (stats.projectedExpenseByMember[memberId] ?? 0) + amount;
        if (isReal) {
          stats.realExpense += amount;
          stats.realExpenseByCategory[categoryId] =
              (stats.realExpenseByCategory[categoryId] ?? 0) + amount;
          stats.realExpenseByMember[memberId] =
              (stats.realExpenseByMember[memberId] ?? 0) + amount;
        }
      }
    }

    return stats;
  }

  static PeriodAccountStats computeGlobal({
    required List<dynamic> transactions,
  }) {
    final stats = PeriodAccountStats();
    for (final t in transactions) {
      if (t['is_automatic'] == true) continue;
      final label = t['label']?.toString().toLowerCase() ?? '';
      if (label.contains('solde') || label.contains('ajustement')) continue;

      final isTransfer =
          t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty;
      if (isTransfer) continue;

      final amount = (t['amount'] as num).toDouble();
      final isReal = (t['status'] ?? 'effective') == 'effective';
      final isIncome = t['type'] == 'income';
      final categoryId = MonthStatsService.normalizeCategoryId(
        t['category']?.toString() ?? 'other',
      );
      final memberId = t['member']?.toString() ?? 'common';

      if (isIncome) {
        stats.projectedIncome += amount;
        stats.projectedIncomeByCategory[categoryId] =
            (stats.projectedIncomeByCategory[categoryId] ?? 0) + amount;
        stats.projectedIncomeByMember[memberId] =
            (stats.projectedIncomeByMember[memberId] ?? 0) + amount;
        if (isReal) {
          stats.realIncome += amount;
          stats.realIncomeByCategory[categoryId] =
              (stats.realIncomeByCategory[categoryId] ?? 0) + amount;
          stats.realIncomeByMember[memberId] =
              (stats.realIncomeByMember[memberId] ?? 0) + amount;
        }
      } else {
        stats.projectedExpense += amount;
        stats.projectedExpenseByCategory[categoryId] =
            (stats.projectedExpenseByCategory[categoryId] ?? 0) + amount;
        stats.projectedExpenseByMember[memberId] =
            (stats.projectedExpenseByMember[memberId] ?? 0) + amount;
        if (isReal) {
          stats.realExpense += amount;
          stats.realExpenseByCategory[categoryId] =
              (stats.realExpenseByCategory[categoryId] ?? 0) + amount;
          stats.realExpenseByMember[memberId] =
              (stats.realExpenseByMember[memberId] ?? 0) + amount;
        }
      }
    }
    return stats;
  }

  static List<MonthlyStats> monthlyHistory({
    required List<dynamic> allTransactions,
    String? accountId,
    int months = 6,
  }) {
    final now = DateTime.now();
    final result = <MonthlyStats>[];

    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      double income = 0;
      double expense = 0;

      for (final t in allTransactions) {
        if (t['is_automatic'] == true) continue;
        final label = t['label']?.toString().toLowerCase() ?? '';
        if (label.contains('solde') || label.contains('ajustement')) continue;

        final date = DateTime.parse(t['date']);
        if (date.isBefore(start) || date.isAfter(end)) continue;

        if (accountId != null) {
          final isTransfer =
              t['target_account'] != null &&
              t['target_account'].toString().isNotEmpty;
          var include = false;
          var isIncome = false;
          if (isTransfer) {
            if (t['target_account'] == accountId) {
              include = true;
              isIncome = true;
            } else if (t['account'] == accountId) {
              include = true;
              isIncome = false;
            }
          } else if (t['account'] == accountId) {
            include = true;
            isIncome = t['type'] == 'income';
          }
          if (!include) continue;
          final amount = (t['amount'] as num).toDouble();
          if (isIncome) {
            income += amount;
          } else {
            expense += amount;
          }
        } else {
          if (t['target_account'] != null &&
              t['target_account'].toString().isNotEmpty) {
            continue;
          }
          final amount = (t['amount'] as num).toDouble();
          if (t['type'] == 'income') {
            income += amount;
          } else {
            expense += amount;
          }
        }
      }

      result.add(
        MonthlyStats(month: start, income: income, expense: expense),
      );
    }

    return result;
  }

  static String categoryDisplayName(
    String id,
    Map<String, String> customNames,
  ) {
    if (customNames.containsKey(id)) return customNames[id]!;
    try {
      return kTransactionCategories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      if (id == 'other') return 'Autre';
      if (id == 'Recurrence') return 'Récurrence';
      return id;
    }
  }
}
