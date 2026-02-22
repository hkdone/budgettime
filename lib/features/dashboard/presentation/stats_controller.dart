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
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;
  final Map<String, double> incomeByMember;
  final Map<String, double> expenseByMember;
  final List<YearlyTrend> yearlyTrends;
  final int selectedYear;

  StatsState({
    this.isLoading = false,
    this.incomeByCategory = const {},
    this.expenseByCategory = const {},
    this.incomeByMember = const {},
    this.expenseByMember = const {},
    this.yearlyTrends = const [],
    this.selectedYear = 0,
  });

  StatsState copyWith({
    bool? isLoading,
    Map<String, double>? incomeByCategory,
    Map<String, double>? expenseByCategory,
    Map<String, double>? incomeByMember,
    Map<String, double>? expenseByMember,
    List<YearlyTrend>? yearlyTrends,
    int? selectedYear,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      incomeByCategory: incomeByCategory ?? this.incomeByCategory,
      expenseByCategory: expenseByCategory ?? this.expenseByCategory,
      incomeByMember: incomeByMember ?? this.incomeByMember,
      expenseByMember: expenseByMember ?? this.expenseByMember,
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

    final incomeByCategory = <String, double>{};
    final expenseByCategory = <String, double>{};
    final incomeByMember = <String, double>{};
    final expenseByMember = <String, double>{};

    for (final t in transactions) {
      // Transfer Neutrality: Exclude transfers from statistics
      if (t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty) {
        continue;
      }

      final amount = (t['amount'] as num).toDouble();
      final type = t['type'];
      final category = t['expand']?['category']?['name'] ?? 'Inconnu';
      final member = t['expand']?['member']?['name'] ?? 'Commun';

      if (type == 'income') {
        incomeByCategory[category] = (incomeByCategory[category] ?? 0) + amount;
        incomeByMember[member] = (incomeByMember[member] ?? 0) + amount;
      } else {
        expenseByCategory[category] =
            (expenseByCategory[category] ?? 0) + amount;
        expenseByMember[member] = (expenseByMember[member] ?? 0) + amount;
      }
    }

    state = state.copyWith(
      isLoading: false,
      incomeByCategory: incomeByCategory,
      expenseByCategory: expenseByCategory,
      incomeByMember: incomeByMember,
      expenseByMember: expenseByMember,
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
