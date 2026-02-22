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

class AccountStats {
  final Map<String, double> realIncomeByCategory;
  final Map<String, double> projectedIncomeByCategory;
  final Map<String, double> realExpenseByCategory;
  final Map<String, double> projectedExpenseByCategory;
  final Map<String, double> realIncomeByMember;
  final Map<String, double> projectedIncomeByMember;
  final Map<String, double> realExpenseByMember;
  final Map<String, double> projectedExpenseByMember;

  AccountStats({
    this.realIncomeByCategory = const {},
    this.projectedIncomeByCategory = const {},
    this.realExpenseByCategory = const {},
    this.projectedExpenseByCategory = const {},
    this.realIncomeByMember = const {},
    this.projectedIncomeByMember = const {},
    this.realExpenseByMember = const {},
    this.projectedExpenseByMember = const {},
  });
}

class StatsState {
  final bool isLoading;
  final Map<String, AccountStats> statsByAccount; // accountId -> AccountStats
  final Map<String, String> accountNames; // accountId -> name
  final List<YearlyTrend> yearlyTrends;
  final int selectedYear;

  StatsState({
    this.isLoading = false,
    this.statsByAccount = const {},
    this.accountNames = const {},
    this.yearlyTrends = const [],
    this.selectedYear = 0,
  });

  StatsState copyWith({
    bool? isLoading,
    Map<String, AccountStats>? statsByAccount,
    Map<String, String>? accountNames,
    List<YearlyTrend>? yearlyTrends,
    int? selectedYear,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      statsByAccount: statsByAccount ?? this.statsByAccount,
      accountNames: accountNames ?? this.accountNames,
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

    final statsByAccount = <String, AccountStats>{};
    final accountNames = <String, String>{};

    for (final t in transactions) {
      // Transfer Neutrality: Exclude transfers from statistics
      if (t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty) {
        continue;
      }

      final accountId = t['account'] ?? 'unknown';
      if (!statsByAccount.containsKey(accountId)) {
        statsByAccount[accountId] = AccountStats(
          realIncomeByCategory: {},
          projectedIncomeByCategory: {},
          realExpenseByCategory: {},
          projectedExpenseByCategory: {},
          realIncomeByMember: {},
          projectedIncomeByMember: {},
          realExpenseByMember: {},
          projectedExpenseByMember: {},
        );

        if (t['expand'] != null && t['expand']['account'] != null) {
          accountNames[accountId] = t['expand']['account']['name'] ?? 'Compte';
        } else {
          accountNames[accountId] = 'Compte';
        }
      }

      final stats = statsByAccount[accountId]!;
      final amount = (t['amount'] as num).toDouble();
      final type = t['type'];
      final status = t['status'] ?? 'effective';
      final isReal = status == 'effective';

      // Always expand category for reliable display
      String category = 'Inconnu';
      if (t['expand'] != null && t['expand']['category'] != null) {
        category = t['expand']['category']['name'] ?? 'Inconnu';
      }

      final member = t['expand']?['member']?['name'] ?? 'Commun';

      if (type == 'income') {
        if (isReal) {
          stats.realIncomeByCategory[category] =
              (stats.realIncomeByCategory[category] ?? 0) + amount;
          stats.realIncomeByMember[member] =
              (stats.realIncomeByMember[member] ?? 0) + amount;
        }
        stats.projectedIncomeByCategory[category] =
            (stats.projectedIncomeByCategory[category] ?? 0) + amount;
        stats.projectedIncomeByMember[member] =
            (stats.projectedIncomeByMember[member] ?? 0) + amount;
      } else {
        if (isReal) {
          stats.realExpenseByCategory[category] =
              (stats.realExpenseByCategory[category] ?? 0) + amount;
          stats.realExpenseByMember[member] =
              (stats.realExpenseByMember[member] ?? 0) + amount;
        }
        stats.projectedExpenseByCategory[category] =
            (stats.projectedExpenseByCategory[category] ?? 0) + amount;
        stats.projectedExpenseByMember[member] =
            (stats.projectedExpenseByMember[member] ?? 0) + amount;
      }
    }

    state = state.copyWith(
      isLoading: false,
      statsByAccount: statsByAccount,
      accountNames: accountNames,
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
