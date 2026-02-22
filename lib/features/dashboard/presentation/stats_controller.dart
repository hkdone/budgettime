import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../../core/start_app.dart';

class YearlyTrend {
  final int year;
  final double income;
  final double expense;
  final double balance;

  YearlyTrend({
    required this.year,
    required this.income,
    required this.expense,
    required this.balance,
  });
}

class StatsState {
  final bool isLoading;
  final Map<String, double> realIncomeByCategory;
  final Map<String, double> projectedIncomeByCategory;
  final Map<String, double> realExpenseByCategory;
  final Map<String, double> projectedExpenseByCategory;
  final Map<String, double> realIncomeByMember;
  final Map<String, double> projectedIncomeByMember;
  final Map<String, double> realExpenseByMember;
  final Map<String, double> projectedExpenseByMember;
  final List<YearlyTrend> yearlyTrends;
  final int selectedYear;

  StatsState({
    this.isLoading = false,
    this.realIncomeByCategory = const {},
    this.projectedIncomeByCategory = const {},
    this.realExpenseByCategory = const {},
    this.projectedExpenseByCategory = const {},
    this.realIncomeByMember = const {},
    this.projectedIncomeByMember = const {},
    this.realExpenseByMember = const {},
    this.projectedExpenseByMember = const {},
    this.yearlyTrends = const [],
    this.selectedYear = 0,
  });

  StatsState copyWith({
    bool? isLoading,
    Map<String, double>? realIncomeByCategory,
    Map<String, double>? projectedIncomeByCategory,
    Map<String, double>? realExpenseByCategory,
    Map<String, double>? projectedExpenseByCategory,
    Map<String, double>? realIncomeByMember,
    Map<String, double>? projectedIncomeByMember,
    Map<String, double>? realExpenseByMember,
    Map<String, double>? projectedExpenseByMember,
    List<YearlyTrend>? yearlyTrends,
    int? selectedYear,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      realIncomeByCategory: realIncomeByCategory ?? this.realIncomeByCategory,
      projectedIncomeByCategory:
          projectedIncomeByCategory ?? this.projectedIncomeByCategory,
      realExpenseByCategory:
          realExpenseByCategory ?? this.realExpenseByCategory,
      projectedExpenseByCategory:
          projectedExpenseByCategory ?? this.projectedExpenseByCategory,
      realIncomeByMember: realIncomeByMember ?? this.realIncomeByMember,
      projectedIncomeByMember:
          projectedIncomeByMember ?? this.projectedIncomeByMember,
      realExpenseByMember: realExpenseByMember ?? this.realExpenseByMember,
      projectedExpenseByMember:
          projectedExpenseByMember ?? this.projectedExpenseByMember,
      yearlyTrends: yearlyTrends ?? this.yearlyTrends,
      selectedYear: selectedYear ?? this.selectedYear,
    );
  }
}

class StatsController extends StateNotifier<StatsState> {
  final TransactionRepository _transactionRepo;

  StatsController(this._transactionRepo)
    : super(StatsState(selectedYear: DateTime.now().year)) {
    loadStats();
    fetchYearlyTrends();
  }

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);

    final start = DateTime(state.selectedYear, 1, 1);
    final end = DateTime(state.selectedYear, 12, 31, 23, 59, 59);

    final transactions = await _transactionRepo.getTransactions(
      start: start,
      end: end,
    );

    final realIncomeByCategory = <String, double>{};
    final projectedIncomeByCategory = <String, double>{};
    final realExpenseByCategory = <String, double>{};
    final projectedExpenseByCategory = <String, double>{};

    final realIncomeByMember = <String, double>{};
    final projectedIncomeByMember = <String, double>{};
    final realExpenseByMember = <String, double>{};
    final projectedExpenseByMember = <String, double>{};

    for (final t in transactions) {
      // Transfer Neutrality: Exclude transfers from statistics
      if (t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty) {
        continue;
      }

      final amount = (t['amount'] as num).toDouble();
      final type = t['type'];
      final status = t['status'] ?? 'effective';
      final isReal = status == 'effective';
      final category = t['expand']?['category']?['name'] ?? 'Inconnu';
      final member = t['expand']?['member']?['name'] ?? 'Commun';

      if (type == 'income') {
        if (isReal) {
          realIncomeByCategory[category] =
              (realIncomeByCategory[category] ?? 0) + amount;
          realIncomeByMember[member] =
              (realIncomeByMember[member] ?? 0) + amount;
        }
        // Projected always includes Real + Actual Projected
        projectedIncomeByCategory[category] =
            (projectedIncomeByCategory[category] ?? 0) + amount;
        projectedIncomeByMember[member] =
            (projectedIncomeByMember[member] ?? 0) + amount;
      } else {
        if (isReal) {
          realExpenseByCategory[category] =
              (realExpenseByCategory[category] ?? 0) + amount;
          realExpenseByMember[member] =
              (realExpenseByMember[member] ?? 0) + amount;
        }
        projectedExpenseByCategory[category] =
            (projectedExpenseByCategory[category] ?? 0) + amount;
        projectedExpenseByMember[member] =
            (projectedExpenseByMember[member] ?? 0) + amount;
      }
    }

    state = state.copyWith(
      isLoading: false,
      realIncomeByCategory: realIncomeByCategory,
      projectedIncomeByCategory: projectedIncomeByCategory,
      realExpenseByCategory: realExpenseByCategory,
      projectedExpenseByCategory: projectedExpenseByCategory,
      realIncomeByMember: realIncomeByMember,
      projectedIncomeByMember: projectedIncomeByMember,
      realExpenseByMember: realExpenseByMember,
      projectedExpenseByMember: projectedExpenseByMember,
    );
  }

  void changeYear(int year) {
    state = state.copyWith(selectedYear: year);
    loadStats();
  }

  Future<void> fetchYearlyTrends() async {
    final currentYear = DateTime.now().year;
    final List<YearlyTrend> trends = [];

    // Fetch last 5 years
    for (int i = 0; i < 5; i++) {
      final year = currentYear - i;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31, 23, 59, 59);

      final transactions = await _transactionRepo.getTransactions(
        start: start,
        end: end,
      );

      double yearIncome = 0;
      double yearExpense = 0;

      for (final t in transactions) {
        if (t['target_account'] != null &&
            t['target_account'].toString().isNotEmpty) {
          continue;
        }
        final amount = (t['amount'] as num).toDouble();
        if (t['type'] == 'income') {
          yearIncome += amount;
        } else {
          yearExpense += amount;
        }
      }

      trends.add(
        YearlyTrend(
          year: year,
          income: yearIncome,
          expense: yearExpense,
          balance: yearIncome - yearExpense,
        ),
      );
    }

    state = state.copyWith(yearlyTrends: trends.reversed.toList());
  }
}

final statsControllerProvider =
    StateNotifierProvider<StatsController, StatsState>((ref) {
      return StatsController(ref.watch(transactionRepositoryProvider));
    });
