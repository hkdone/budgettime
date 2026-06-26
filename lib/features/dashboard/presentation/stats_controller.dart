import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../../core/start_app.dart';
import '../../transactions/domain/categories.dart';
import '../../recurrences/data/recurrence_repository_impl.dart';
import '../presentation/widgets/statistics_widgets.dart';

enum StatsGranularity { year, quarter, month }

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
  final Map<String, AccountStats> statsByAccount;
  final Map<String, String> accountNames;
  final List<YearlyTrend> yearlyTrends;
  final List<MonthlyStats> monthlyTrendsForYear;
  final int selectedYear;
  final StatsGranularity granularity;
  final int selectedMonth;
  final int selectedQuarter;
  final String? filterAccountId;
  final Map<String, String> memberNames;
  final Map<String, String> categoryNames;

  StatsState({
    this.isLoading = false,
    this.statsByAccount = const {},
    this.accountNames = const {},
    this.yearlyTrends = const [],
    this.monthlyTrendsForYear = const [],
    this.selectedYear = 0,
    this.granularity = StatsGranularity.year,
    this.selectedMonth = 1,
    this.selectedQuarter = 1,
    this.filterAccountId,
    this.memberNames = const {},
    this.categoryNames = const {},
  });

  StatsState copyWith({
    bool? isLoading,
    Map<String, AccountStats>? statsByAccount,
    Map<String, String>? accountNames,
    List<YearlyTrend>? yearlyTrends,
    List<MonthlyStats>? monthlyTrendsForYear,
    int? selectedYear,
    StatsGranularity? granularity,
    int? selectedMonth,
    int? selectedQuarter,
    String? filterAccountId,
    bool clearFilterAccount = false,
    Map<String, String>? memberNames,
    Map<String, String>? categoryNames,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      statsByAccount: statsByAccount ?? this.statsByAccount,
      accountNames: accountNames ?? this.accountNames,
      yearlyTrends: yearlyTrends ?? this.yearlyTrends,
      monthlyTrendsForYear: monthlyTrendsForYear ?? this.monthlyTrendsForYear,
      selectedYear: selectedYear ?? this.selectedYear,
      granularity: granularity ?? this.granularity,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedQuarter: selectedQuarter ?? this.selectedQuarter,
      filterAccountId: clearFilterAccount
          ? null
          : (filterAccountId ?? this.filterAccountId),
      memberNames: memberNames ?? this.memberNames,
      categoryNames: categoryNames ?? this.categoryNames,
    );
  }

  Map<String, AccountStats> get visibleStatsByAccount {
    if (filterAccountId == null) return statsByAccount;
    final stats = statsByAccount[filterAccountId];
    if (stats == null) return {};
    return {filterAccountId!: stats};
  }

  String periodLabel() {
    switch (granularity) {
      case StatsGranularity.year:
        return 'Année $selectedYear';
      case StatsGranularity.quarter:
        return 'T$selectedQuarter $selectedYear';
      case StatsGranularity.month:
        const months = [
          'Janvier',
          'Février',
          'Mars',
          'Avril',
          'Mai',
          'Juin',
          'Juillet',
          'Août',
          'Septembre',
          'Octobre',
          'Novembre',
          'Décembre',
        ];
        return '${months[selectedMonth - 1]} $selectedYear';
    }
  }
}

class StatsController extends StateNotifier<StatsState> {
  final TransactionRepository _transactionRepo;
  final Ref _ref;

  StatsController(this._transactionRepo, this._ref)
    : super(
        StatsState(
          selectedYear: DateTime.now().year,
          selectedMonth: DateTime.now().month,
          selectedQuarter: ((DateTime.now().month - 1) ~/ 3) + 1,
        ),
      ) {
    loadStats();
    fetchYearlyTrends();
  }

  (DateTime, DateTime) _periodBounds() {
    switch (state.granularity) {
      case StatsGranularity.year:
        return (
          DateTime(state.selectedYear, 1, 1, 0, 0, 0),
          DateTime(state.selectedYear, 12, 31, 23, 59, 59),
        );
      case StatsGranularity.quarter:
        final startMonth = (state.selectedQuarter - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        return (
          DateTime(state.selectedYear, startMonth, 1, 0, 0, 0),
          DateTime(state.selectedYear, endMonth + 1, 0, 23, 59, 59),
        );
      case StatsGranularity.month:
        return (
          DateTime(state.selectedYear, state.selectedMonth, 1, 0, 0, 0),
          DateTime(
            state.selectedYear,
            state.selectedMonth + 1,
            0,
            23,
            59,
            59,
          ),
        );
    }
  }

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);

    final (start, end) = _periodBounds();

    try {
      final transactions = await _transactionRepo.getTransactions(
        start: start,
        end: end,
        accountId: state.filterAccountId,
      );

      final statsByAccount = <String, AccountStats>{};
      final accountNames = <String, String>{};
      final memberNames = <String, String>{};
      final categoryNames = <String, String>{};
      final recurrenceCategoryMap = <String, String>{};

      for (final cat in kTransactionCategories) {
        categoryNames[cat.id] = cat.name;
      }

      try {
        final catRepo = _ref.read(categoryRepositoryProvider);
        final customCats = await catRepo.getCategories();
        for (final cat in customCats) {
          categoryNames.putIfAbsent(cat.id, () => cat.name);
        }
      } catch (e) {
        debugPrint('Warning: Could not fetch custom categories: $e');
      }

      try {
        final memberRepo = _ref.read(memberRepositoryProvider);
        final members = await memberRepo.getMembers();
        for (final m in members) {
          memberNames[m.id] = m.name;
        }
      } catch (e) {
        debugPrint('Warning: Could not fetch members: $e');
      }

      try {
        final recurrenceRepo = _ref.read(recurrenceRepositoryProvider);
        final recurrences = await recurrenceRepo.getRecurrences();
        for (final r in recurrences) {
          if (r.categoryId != null) {
            recurrenceCategoryMap[r.id] = r.categoryId!;
          }
        }
      } catch (e) {
        debugPrint('Warning: Could not fetch recurrences: $e');
      }

      memberNames.putIfAbsent('common', () => 'Commun');

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
          memberNames: memberNames,
          categoryNames: categoryNames,
          recurrenceCategoryMap: recurrenceCategoryMap,
          isOutgoing: true,
        );

        if (targetId != null && targetId.isNotEmpty) {
          _processTransactionForAccount(
            t: t,
            accountId: targetId,
            statsByAccount: statsByAccount,
            accountNames: accountNames,
            memberNames: memberNames,
            categoryNames: categoryNames,
            recurrenceCategoryMap: recurrenceCategoryMap,
            isOutgoing: false,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        statsByAccount: statsByAccount,
        accountNames: accountNames,
        memberNames: memberNames,
        categoryNames: categoryNames,
      );
    } catch (e, stack) {
      debugPrint('Error in loadStats: $e\n$stack');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await loadStats();
    await fetchYearlyTrends();
  }

  void setFilterAccount(String? accountId) {
    state = state.copyWith(
      filterAccountId: accountId,
      clearFilterAccount: accountId == null,
    );
    loadStats();
    fetchYearlyTrends();
  }

  void changeYear(int year) {
    state = state.copyWith(selectedYear: year);
    loadStats();
    fetchYearlyTrends();
  }

  void changeGranularity(StatsGranularity granularity) {
    state = state.copyWith(granularity: granularity);
    loadStats();
  }

  void changeMonth(int month) {
    state = state.copyWith(selectedMonth: month);
    loadStats();
  }

  void changeQuarter(int quarter) {
    state = state.copyWith(selectedQuarter: quarter);
    loadStats();
  }

  void _processTransactionForAccount({
    required Map<String, dynamic> t,
    required String accountId,
    required Map<String, AccountStats> statsByAccount,
    required Map<String, String> accountNames,
    required Map<String, String> memberNames,
    required Map<String, String> categoryNames,
    required Map<String, String> recurrenceCategoryMap,
    required bool isOutgoing,
  }) {
    if (!statsByAccount.containsKey(accountId)) {
      statsByAccount[accountId] = AccountStats();

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
      categoryNames.putIfAbsent(categoryId, () => expCat['name'] ?? 'Autre');
    } else if (t['category'] != null) {
      categoryId = t['category'].toString();
    }

    if (categoryId == 'Recurrence' ||
        categoryId == 'other' ||
        categoryId == 'Recurrence'.toLowerCase()) {
      final String? rId = t['recurrence'];
      if (rId != null && recurrenceCategoryMap.containsKey(rId)) {
        categoryId = recurrenceCategoryMap[rId]!;
      }
    }

    String memberId = 'common';
    if (t['expand'] != null && t['expand']['member'] != null) {
      final dynamic expMem = t['expand']['member'];
      memberId = expMem['id'] ?? 'common';
      memberNames.putIfAbsent(memberId, () => expMem['name'] ?? 'Commun');
    } else if (t['member'] != null) {
      memberId = t['member'].toString();
    }
    memberNames.putIfAbsent('common', () => 'Commun');

    final bool isIncome;
    if (t['target_account'] != null &&
        t['target_account'].toString().isNotEmpty) {
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

  Future<void> fetchYearlyTrends() async {
    final currentYear = DateTime.now().year;
    const yearsBack = 5;
    final startYear = currentYear - yearsBack;

    try {
      final start = DateTime(startYear, 1, 1);
      final end = DateTime(currentYear, 12, 31, 23, 59, 59);

      final transactions = await _transactionRepo.getTransactions(
        start: start,
        end: end,
        accountId: state.filterAccountId,
      );

      final incomeByYear = <int, double>{};
      final expenseByYear = <int, double>{};
      final incomeByMonth = <int, double>{};
      final expenseByMonth = <int, double>{};

      for (final t in transactions) {
        final label = t['label']?.toString().toLowerCase() ?? '';
        if (label.contains('solde') || label.contains('ajustement')) continue;

        if (t['target_account'] != null &&
            t['target_account'].toString().isNotEmpty) {
          continue;
        }

        final date = DateTime.parse(t['date']);
        final year = date.year;
        final month = date.month;
        final amount = (t['amount'] as num).toDouble();

        if (t['type'] == 'income') {
          incomeByYear[year] = (incomeByYear[year] ?? 0) + amount;
          if (year == state.selectedYear) {
            incomeByMonth[month] = (incomeByMonth[month] ?? 0) + amount;
          }
        } else {
          expenseByYear[year] = (expenseByYear[year] ?? 0) + amount;
          if (year == state.selectedYear) {
            expenseByMonth[month] = (expenseByMonth[month] ?? 0) + amount;
          }
        }
      }

      final trends = <YearlyTrend>[];
      for (var year = startYear; year <= currentYear; year++) {
        final income = incomeByYear[year] ?? 0;
        final expense = expenseByYear[year] ?? 0;
        trends.add(
          YearlyTrend(
            year: year,
            income: income,
            expense: expense,
            balance: income - expense,
          ),
        );
      }

      final monthly = <MonthlyStats>[];
      for (var m = 1; m <= 12; m++) {
        monthly.add(
          MonthlyStats(
            month: DateTime(state.selectedYear, m, 1),
            income: incomeByMonth[m] ?? 0,
            expense: expenseByMonth[m] ?? 0,
          ),
        );
      }

      state = state.copyWith(
        yearlyTrends: trends,
        monthlyTrendsForYear: monthly,
      );
    } catch (e, stack) {
      debugPrint('Error in fetchYearlyTrends: $e\n$stack');
    }
  }
}

final statsControllerProvider =
    StateNotifierProvider<StatsController, StatsState>((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      return StatsController(repo, ref);
    });
