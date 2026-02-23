import 'package:flutter/foundation.dart';
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

    // Retour au calendrier civil pour l'analyse annuelle (plus intuitif)
    final start = DateTime(state.selectedYear, 1, 1, 0, 0, 0);
    final end = DateTime(state.selectedYear, 12, 31, 23, 59, 59);

    try {
      final transactions = await _transactionRepo.getTransactions(
        start: start,
        end: end,
      );

      final statsByAccount = <String, AccountStats>{};
      final accountNames = <String, String>{};

      for (final t in transactions) {
        if (t['is_automatic'] == true) continue;
        final label = t['label']?.toString().toLowerCase() ?? '';
        if (label.contains('solde') || label.contains('ajustement')) continue;

        final String? tAccount = t['account'];
        final String? tTargetAccount = t['target_account'];

        final accountId = tAccount ?? 'unknown';
        final targetId = tTargetAccount;

        _processTransactionForAccount(
          t: t,
          accountId: accountId,
          statsByAccount: statsByAccount,
          accountNames: accountNames,
          isOutgoing: true,
        );

        if (targetId != null && targetId.isNotEmpty) {
          _processTransactionForAccount(
            t: t,
            accountId: targetId,
            statsByAccount: statsByAccount,
            accountNames: accountNames,
            isOutgoing: false,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        statsByAccount: statsByAccount,
        accountNames: accountNames,
      );
    } catch (e, stack) {
      debugPrint('Error in loadStats: $e\n$stack');
      state = state.copyWith(isLoading: false);
    }
  }

  void _processTransactionForAccount({
    required Map<String, dynamic> t,
    required String accountId,
    required Map<String, AccountStats> statsByAccount,
    required Map<String, String> accountNames,
    required bool isOutgoing,
  }) {
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

      // Try to find account name in expand
      if (t['expand'] != null) {
        if (isOutgoing && t['expand']['account'] != null) {
          final dynamic expAcc = t['expand']['account'];
          accountNames[accountId] = expAcc['name'] ?? 'Compte';
        } else if (!isOutgoing && t['expand']['target_account'] != null) {
          final dynamic expTarget = t['expand']['target_account'];
          accountNames[accountId] = expTarget['name'] ?? 'Compte';
        }
      }
      accountNames.putIfAbsent(accountId, () => 'Compte');
    }

    final stats = statsByAccount[accountId]!;
    final amount = (t['amount'] as num).toDouble();
    final status = t['status'] ?? 'effective';
    final isReal = status == 'effective';

    String categoryId = 'other';
    if (t['expand'] != null && t['expand']['category'] != null) {
      final dynamic expCat = t['expand']['category'];
      categoryId = expCat['id'] ?? 'other';
    } else if (t['category'] != null) {
      categoryId = t['category'].toString();
    }

    String memberId = 'common';
    if (t['expand'] != null && t['expand']['member'] != null) {
      final dynamic expMem = t['expand']['member'];
      memberId = expMem['id'] ?? 'common';
    } else if (t['member'] != null) {
      memberId = t['member'].toString();
    }

    // Type logic
    final bool isIncome;
    if (t['target_account'] != null &&
        t['target_account'].toString().isNotEmpty) {
      // It's a transfer
      isIncome = !isOutgoing;
    } else {
      isIncome = t['type'] == 'income';
    }

    if (isIncome) {
      if (isReal) {
        stats.realIncomeByCategory[categoryId] =
            (stats.realIncomeByCategory[categoryId] ?? 0) + amount;
        stats.realIncomeByMember[memberId] =
            (stats.realIncomeByMember[memberId] ?? 0) + amount;
      }
      stats.projectedIncomeByCategory[categoryId] =
          (stats.projectedIncomeByCategory[categoryId] ?? 0) + amount;
      stats.projectedIncomeByMember[memberId] =
          (stats.projectedIncomeByMember[memberId] ?? 0) + amount;
    } else {
      if (isReal) {
        stats.realExpenseByCategory[categoryId] =
            (stats.realExpenseByCategory[categoryId] ?? 0) + amount;
        stats.realExpenseByMember[memberId] =
            (stats.realExpenseByMember[memberId] ?? 0) + amount;
      }
      stats.projectedExpenseByCategory[categoryId] =
          (stats.projectedExpenseByCategory[categoryId] ?? 0) + amount;
      stats.projectedExpenseByMember[memberId] =
          (stats.projectedExpenseByMember[memberId] ?? 0) + amount;
    }
  }

  void changeYear(int year) {
    state = state.copyWith(selectedYear: year);
    loadStats();
  }

  Future<void> fetchYearlyTrends() async {
    final currentYear = DateTime.now().year;
    final List<YearlyTrend> trends = [];

    try {
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
          // Technical Filter: Hide purely technical adjustments
          final label = t['label']?.toString().toLowerCase() ?? '';
          if (label.contains('solde') || label.contains('ajustement')) continue;

          // Transfer logic: Neutralize transfers for global yearly trends
          final String? tTargetAccount = t['target_account'];
          if (tTargetAccount != null && tTargetAccount.isNotEmpty) {
            continue; // Skip transfers for global yearly trends
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
    } catch (e, stack) {
      debugPrint('Error in fetchYearlyTrends: $e\n$stack');
    }
  }
}

final statsControllerProvider =
    StateNotifierProvider<StatsController, StatsState>((ref) {
      return StatsController(ref.watch(transactionRepositoryProvider));
    });
