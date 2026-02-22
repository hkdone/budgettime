import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';
import '../../transactions/data/transaction_repository_impl.dart';

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

  StatisticsController(this._repository) : super(const AsyncValue.loading());

  Future<void> loadStats({
    required DateTime targetMonth,
    String? accountId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Fetch data for the target month (for Pie Chart)
      final start = DateTime(targetMonth.year, targetMonth.month, 1);
      final end = DateTime(
        targetMonth.year,
        targetMonth.month + 1,
        0,
        23,
        59,
        59,
      );

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
        final amount = (t['amount'] as num).toDouble();
        final type = t['type'];
        // Safe access to member ID
        String memberId = '';
        if (t['expand'] != null && t['expand']['member'] != null) {
          memberId = t['expand']['member']['id'] ?? '';
        } else if (t['member'] != null) {
          memberId = t['member'].toString();
        }
        if (memberId.isEmpty) memberId = 'common';
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
        final monthStart = DateTime(targetMonth.year, targetMonth.month - i, 1);
        final monthEnd = DateTime(
          monthStart.year,
          monthStart.month + 1,
          0,
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
          final amount = (t['amount'] as num).toDouble();
          if (t['type'] == 'income') mIncome += amount;
          if (t['type'] == 'expense') mExpense += amount;
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
      return StatisticsController(repo);
    });

final accountStatsProvider = FutureProvider.family<StatisticsData, String?>((
  ref,
  accountId,
) async {
  final repo =
      ref.watch(transactionRepositoryProvider) as TransactionRepositoryImpl;

  // 1. Fetch data for the target month (for Pie Chart)
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

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
    // Transfer Neutrality: Exclude transfers from statistics
    if (t['target_account'] != null &&
        t['target_account'].toString().isNotEmpty) {
      continue;
    }

    final amount = (t['amount'] as num).toDouble();
    final type = t['type'];

    // Safe access to category and member IDs/names
    String catId = t['category'] ?? 'other';
    if (t['expand'] != null && t['expand']['category'] != null) {
      catId = t['expand']['category']['id'] ?? catId;
    }

    String mId = 'common';
    if (t['expand'] != null && t['expand']['member'] != null) {
      mId = t['expand']['member']['id'] ?? 'common';
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
    final monthStart = DateTime(now.year, now.month - i, 1);
    final monthEnd = DateTime(
      monthStart.year,
      monthStart.month + 1,
      0,
      23,
      59,
      59,
    );

    final monthTrans = await repo.getTransactions(
      start: monthStart,
      end: monthEnd,
      accountId: accountId,
    );

    double mIncome = 0;
    double mExpense = 0;
    for (final t in monthTrans) {
      final amount = (t['amount'] as num).toDouble();
      if (t['type'] == 'income') mIncome += amount;
      if (t['type'] == 'expense') mExpense += amount;
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
