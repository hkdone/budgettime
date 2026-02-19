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

class StatisticsData {
  final List<CategoryStats> expenseByCategory;
  final List<MonthlyStats> history;
  final double totalExpense;
  final double totalIncome;

  StatisticsData({
    required this.expenseByCategory,
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
      // Define start/end based on fiscal day (assuming standard 1st for now, can be improved)
      // Actually, we should use the same logic as Dashboard if possible, but let's stick to calendar month for stats simplicity for now
      // Or better: ask Settings for fiscal day. For now, calendar month.
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

      // Aggregate Category Expenses
      final categoryMap = <String, double>{};
      double totalExpense = 0;
      double totalIncome = 0;

      for (final t in transactions) {
        final amount = (t['amount'] as num).toDouble();
        final type = t['type'];
        // Filter out transfers if needed? usually yes.
        if (type == 'expense') {
          totalExpense += amount;
          final catId = t['category'] ?? 'other';
          categoryMap[catId] = (categoryMap[catId] ?? 0) + amount;
        } else if (type == 'income') {
          totalIncome += amount;
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
