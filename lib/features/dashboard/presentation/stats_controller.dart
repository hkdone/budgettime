import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../settings/presentation/settings_controller.dart';
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
  final Ref _ref;

  StatsController(this._transactionRepo, this._ref)
    : super(StatsState(selectedYear: DateTime.now().year)) {
    loadStats();
    fetchYearlyTrends();
  }

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);

    // Aligner sur l'année fiscale (12 mois glissants)
    final settingsAsync = _ref.read(settingsControllerProvider);
    final int fiscalDay = settingsAsync.value?.fiscalDayStart ?? 1;

    // Adjust the annual range to cover 12 fiscal months
    final start = DateTime(state.selectedYear - 1, 12, fiscalDay, 0, 0, 0);
    final end = DateTime(state.selectedYear, 12, fiscalDay - 1, 23, 59, 59);

    final transactions = await _transactionRepo.getTransactions(
      start: start,
      end: end,
    );

    final statsByAccount = <String, AccountStats>{};
    final accountNames = <String, String>{};

    for (final t in transactions) {
      // Technical Filter
      final label = t['label']?.toString().toLowerCase() ?? '';
      if (label.contains('solde') || label.contains('ajustement')) continue;

      final String? tAccount = t['account'];
      final String? tTargetAccount = t['target_account'];

      // Global View: Neutralize transfers
      // Transfers are handled per account, not globally in this loop.
      // The original logic for processing source and target accounts is retained.

      final accountId = tAccount ?? 'unknown';
      final targetId = tTargetAccount;

      // Handle main account stats
      _processTransactionForAccount(
        t: t,
        accountId: accountId,
        statsByAccount: statsByAccount,
        accountNames: accountNames,
        isOutgoing: true,
      );

      // Handle target account stats if transfer
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
          accountNames[accountId] = t['expand']['account']['name'] ?? 'Compte';
        } else if (!isOutgoing && t['expand']['target_account'] != null) {
          accountNames[accountId] =
              t['expand']['target_account']['name'] ?? 'Compte';
        }
      }
      accountNames.putIfAbsent(accountId, () => 'Compte');
    }

    final stats = statsByAccount[accountId]!;
    final amount = (t['amount'] as num).toDouble();
    final status = t['status'] ?? 'effective';
    final isReal = status == 'effective';

    String category = 'Commun';
    if (t['expand'] != null && t['expand']['category'] != null) {
      category = t['expand']['category']['name'] ?? 'Commun';
    }

    final member = t['expand']?['member']?['name'] ?? 'Commun';

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
  }
}

final statsControllerProvider =
    StateNotifierProvider<StatsController, StatsState>((ref) {
      return StatsController(ref.watch(transactionRepositoryProvider), ref);
    });
