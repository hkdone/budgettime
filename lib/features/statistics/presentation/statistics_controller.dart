import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';
import '../../transactions/data/transaction_repository_impl.dart';
import '../../settings/presentation/settings_controller.dart';

class MonthlyStats {
  final DateTime month;
  final double income;
  final double expense;

  MonthlyStats({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class CategoryStats {
  final String categoryId;
  final double amount;
  final double percentage;

  CategoryStats({
    required this.categoryId,
    required this.amount,
    required this.percentage,
  });
}

class MemberStats {
  final String memberId;
  final double amount;
  final double percentage;

  MemberStats({
    required this.memberId,
    required this.amount,
    required this.percentage,
  });
}

class StatisticsData {
  final List<CategoryStats> expenseByCategory;
  final List<MemberStats> expenseByMember;
  final List<MemberStats> incomeByMember;
  final List<MonthlyStats> history;
  final double totalExpense;
  final double totalIncome;

  StatisticsData({
    required this.expenseByCategory,
    required this.expenseByMember,
    required this.incomeByMember,
    required this.history,
    required this.totalExpense,
    required this.totalIncome,
  });
}

class StatisticsController extends StateNotifier<AsyncValue<StatisticsData>> {
  final TransactionRepositoryImpl _repository;
  final Ref _ref;

  StatisticsController(this._repository, this._ref)
    : super(const AsyncValue.loading());

  Future<void> loadStats({
    required DateTime targetMonth,
    String? accountId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Fetch data for the target month (for Pie Chart)
      // 1. Get Settings for fiscal day
      final settingsAsync = _ref.read(settingsControllerProvider);
      final int fiscalDay = settingsAsync.value?.fiscalDayStart ?? 1;

      // 2. Calculate Fiscal Period Month
      late DateTime start, end;
      if (targetMonth.day >= fiscalDay) {
        start = DateTime(targetMonth.year, targetMonth.month, fiscalDay);
        final nextMonthStart = DateTime(
          targetMonth.year,
          targetMonth.month + 1,
          fiscalDay,
        );
        end = nextMonthStart.subtract(const Duration(days: 1));
      } else {
        start = DateTime(targetMonth.year, targetMonth.month - 1, fiscalDay);
        final currentMonthStart = DateTime(
          targetMonth.year,
          targetMonth.month,
          fiscalDay,
        );
        end = currentMonthStart.subtract(const Duration(days: 1));
      }

      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);

      final transactions = await _repository.getTransactions(
        start: start,
        end: end,
        accountId: accountId,
      );

      // Aggregate Category Expenses & Member Stats
      final categoryMap = <String, double>{};
      final memberExpenseMap = <String, double>{};
      final memberIncomeMap = <String, double>{};
      double totalExpense = 0;
      double totalIncome = 0;

      for (final t in transactions) {
        if (t['is_automatic'] == true) continue;
        final label = t['label']?.toString().toLowerCase() ?? '';
        if (label.contains('solde') || label.contains('ajustement')) continue;

        final amount = (t['amount'] as num).toDouble();
        String type = t['type'];
        final isTransfer =
            t['target_account'] != null &&
            t['target_account'].toString().isNotEmpty;

        // Transfer logic for stats
        if (isTransfer) {
          if (accountId == null) {
            // Global view: Transfers are neutral
            continue;
          } else {
            // Account view: Determine if it's income or expense for THIS account
            final sourceAccId = t['account'];
            final targetAccId = t['target_account'];

            if (accountId == targetAccId) {
              type = 'income';
            } else if (accountId == sourceAccId) {
              type = 'expense';
            } else {
              // Should not happen with current getTransactions but for safety:
              continue;
            }
          }
        }

        // Safe access to member ID (unified via TransactionRepositoryImpl)
        String memberId = 'common';
        if (t['expand'] != null && t['expand']['member'] != null) {
          final dynamic expandedMember = t['expand']['member'];
          memberId = expandedMember['id'] ?? 'common';
        }
        if (type == 'expense') {
          totalExpense += amount;
          final catId = t['category'] ?? 'other';
          categoryMap[catId] = (categoryMap[catId] ?? 0) + amount;
          memberExpenseMap[memberId] =
              (memberExpenseMap[memberId] ?? 0) + amount;
        } else if (type == 'income') {
          totalIncome += amount;
          memberIncomeMap[memberId] = (memberIncomeMap[memberId] ?? 0) + amount;
        }
      }

      final expenseByCategory = categoryMap.entries.map((e) {
        return CategoryStats(
          categoryId: e.key,
          amount: e.value,
          percentage: totalExpense > 0 ? (e.value / totalExpense) * 100 : 0,
        );
      }).toList();

      // Sort by amount desc
      expenseByCategory.sort((a, b) => b.amount.compareTo(a.amount));

      // Build Member Stats
      final expenseByMember = memberExpenseMap.entries.map((e) {
        return MemberStats(
          memberId: e.key,
          amount: e.value,
          percentage: totalExpense > 0 ? (e.value / totalExpense) * 100 : 0,
        );
      }).toList();
      expenseByMember.sort((a, b) => b.amount.compareTo(a.amount));

      final incomeByMember = memberIncomeMap.entries.map((e) {
        return MemberStats(
          memberId: e.key,
          amount: e.value,
          percentage: totalIncome > 0 ? (e.value / totalIncome) * 100 : 0,
        );
      }).toList();
      incomeByMember.sort((a, b) => b.amount.compareTo(a.amount));

      // 2. Fetch history (Last 6 months)
      final history = <MonthlyStats>[];
      for (int i = 5; i >= 0; i--) {
        final baseDate = DateTime(
          targetMonth.year,
          targetMonth.month - i,
          fiscalDay,
        );
        late DateTime monthStart, monthEnd;

        monthStart = baseDate;
        final nextMonthStart = DateTime(
          monthStart.year,
          monthStart.month + 1,
          fiscalDay,
        );
        monthEnd = nextMonthStart.subtract(const Duration(days: 1));

        monthStart = DateTime(
          monthStart.year,
          monthStart.month,
          monthStart.day,
          0,
          0,
          0,
        );
        monthEnd = DateTime(
          monthEnd.year,
          monthEnd.month,
          monthEnd.day,
          23,
          59,
          59,
        );

        final monthTrans = await _repository.getTransactions(
          start: monthStart,
          end: monthEnd,
          accountId: accountId,
        );

        double mIncome = 0;
        double mExpense = 0;
        for (final t in monthTrans) {
          if (t['is_automatic'] == true) continue;
          final label = t['label']?.toString().toLowerCase() ?? '';
          if (label.contains('solde') || label.contains('ajustement')) continue;

          final amount = (t['amount'] as num).toDouble();
          String type = t['type'];
          final isTransfer =
              t['target_account'] != null &&
              t['target_account'].toString().isNotEmpty;

          if (isTransfer) {
            if (accountId == null) continue;
            final sourceAccId = t['account'];
            final targetAccId = t['target_account'];
            if (accountId == targetAccId) {
              type = 'income';
            } else if (accountId == sourceAccId) {
              type = 'expense';
            } else {
              continue;
            }
          }

          if (type == 'income') mIncome += amount;
          if (type == 'expense') mExpense += amount;
        }
        history.add(
          MonthlyStats(month: monthStart, income: mIncome, expense: mExpense),
        );
      }

      return StatisticsData(
        expenseByCategory: expenseByCategory,
        expenseByMember: expenseByMember,
        incomeByMember: incomeByMember,
        history: history,
        totalExpense: totalExpense,
        totalIncome: totalIncome,
      );
    });
  }
}

final statisticsControllerProvider =
    StateNotifierProvider<StatisticsController, AsyncValue<StatisticsData>>((
      ref,
    ) {
      final repo =
          ref.watch(transactionRepositoryProvider) as TransactionRepositoryImpl;
      return StatisticsController(repo, ref);
    });

final accountStatsProvider = FutureProvider.family<StatisticsData, String?>((
  ref,
  accountId,
) async {
  final repo =
      ref.watch(transactionRepositoryProvider) as TransactionRepositoryImpl;

  // 1. Get Settings for fiscal day
  final settingsAsync = ref.read(settingsControllerProvider);
  final int fiscalDay = settingsAsync.value?.fiscalDayStart ?? 1;

  // 1b. Fetch data for the current fiscal period
  final now = DateTime.now();
  late DateTime start, end;

  if (now.day >= fiscalDay) {
    start = DateTime(now.year, now.month, fiscalDay);
    final nextMonthStart = DateTime(now.year, now.month + 1, fiscalDay);
    end = nextMonthStart.subtract(const Duration(days: 1));
  } else {
    start = DateTime(now.year, now.month - 1, fiscalDay);
    final currentMonthStart = DateTime(now.year, now.month, fiscalDay);
    end = currentMonthStart.subtract(const Duration(days: 1));
  }

  start = DateTime(start.year, start.month, start.day, 0, 0, 0);
  end = DateTime(end.year, end.month, end.day, 23, 59, 59);

  final transactions = await repo.getTransactions(
    start: start,
    end: end,
    accountId: accountId,
  );

  // Aggregate Category Expenses & Member Stats
  final categoryMap = <String, double>{};
  final memberExpenseMap = <String, double>{};
  final memberIncomeMap = <String, double>{};
  double totalExpense = 0;
  double totalIncome = 0;

  for (final t in transactions) {
    if (t['is_automatic'] == true) continue;
    final label = t['label']?.toString().toLowerCase() ?? '';
    if (label.contains('solde') || label.contains('ajustement')) continue;

    final amount = (t['amount'] as num).toDouble();
    String type = t['type'];
    final isTransfer =
        t['target_account'] != null &&
        t['target_account'].toString().isNotEmpty;

    if (isTransfer) {
      if (accountId == null) {
        continue;
      } else {
        final sourceAccId = t['account'];
        final targetAccId = t['target_account'];

        if (accountId == targetAccId) {
          type = 'income';
        } else if (accountId == sourceAccId) {
          type = 'expense';
        } else {
          continue;
        }
      }
    }

    // Safe access to category and member IDs (unified mapping)
    String catId = t['category'] ?? 'other';
    if (t['expand'] != null && t['expand']['category'] != null) {
      final dynamic expCat = t['expand']['category'];
      catId = expCat['id'] ?? catId;
    }

    String mId = 'common';
    if (t['expand'] != null && t['expand']['member'] != null) {
      final dynamic expMem = t['expand']['member'];
      mId = expMem['id'] ?? 'common';
    } else if (t['member'] != null) {
      mId = t['member'].toString();
    }

    if (type == 'expense') {
      totalExpense += amount;
      categoryMap[catId] = (categoryMap[catId] ?? 0) + amount;
      memberExpenseMap[mId] = (memberExpenseMap[mId] ?? 0) + amount;
    } else if (type == 'income') {
      totalIncome += amount;
      memberIncomeMap[mId] = (memberIncomeMap[mId] ?? 0) + amount;
    }
  }

  final expenseByCategory = categoryMap.entries.map((e) {
    return CategoryStats(
      categoryId: e.key,
      amount: e.value,
      percentage: totalExpense > 0 ? (e.value / totalExpense) * 100 : 0,
    );
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  final expenseByMember = memberExpenseMap.entries.map((e) {
    return MemberStats(
      memberId: e.key,
      amount: e.value,
      percentage: totalExpense > 0 ? (e.value / totalExpense) * 100 : 0,
    );
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  final incomeByMember = memberIncomeMap.entries.map((e) {
    return MemberStats(
      memberId: e.key,
      amount: e.value,
      percentage: totalIncome > 0 ? (e.value / totalIncome) * 100 : 0,
    );
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  // 2. Fetch history (Last 6 months)
  final history = <MonthlyStats>[];
  for (int i = 5; i >= 0; i--) {
    final baseDate = DateTime(now.year, now.month - i, fiscalDay);
    late DateTime mStart, mEnd;

    mStart = baseDate;
    final nMonthStart = DateTime(mStart.year, mStart.month + 1, fiscalDay);
    mEnd = nMonthStart.subtract(const Duration(days: 1));

    mStart = DateTime(mStart.year, mStart.month, mStart.day, 0, 0, 0);
    mEnd = DateTime(mEnd.year, mEnd.month, mEnd.day, 23, 59, 59);

    final monthTrans = await repo.getTransactions(
      start: mStart,
      end: mEnd,
      accountId: accountId,
    );

    double mIncome = 0;
    double mExpense = 0;
    for (final t in monthTrans) {
      if (t['is_automatic'] == true) continue;
      final label = t['label']?.toString().toLowerCase() ?? '';
      if (label.contains('solde') || label.contains('ajustement')) continue;

      final amount = (t['amount'] as num).toDouble();
      String type = t['type'];
      final isTransfer =
          t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty;

      if (isTransfer) {
        if (accountId == null) continue;
        final sourceAccId = t['account'];
        final targetAccId = t['target_account'];
        if (accountId == targetAccId) {
          type = 'income';
        } else if (accountId == sourceAccId) {
          type = 'expense';
        } else {
          continue;
        }
      }

      if (type == 'income') mIncome += amount;
      if (type == 'expense') mExpense += amount;
    }
    history.add(
      MonthlyStats(month: mStart, income: mIncome, expense: mExpense),
    );
  }

  return StatisticsData(
    expenseByCategory: expenseByCategory,
    expenseByMember: expenseByMember,
    incomeByMember: incomeByMember,
    history: history,
    totalExpense: totalExpense,
    totalIncome: totalIncome,
  );
});
