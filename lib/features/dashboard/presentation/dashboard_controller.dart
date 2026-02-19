import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../accounts/data/account_repository_impl.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../transactions/domain/transaction_repository.dart';

class DashboardState {
  final List<dynamic> transactions;
  final List<Account> accounts;
  final Account? selectedAccount;
  final DateTime start;
  final DateTime end;
  final double effectiveBalance;
  final double projectedBalance;
  final bool isLoading;
  final String? error;

  DashboardState({
    required this.transactions,
    this.accounts = const [],
    this.selectedAccount,
    required this.start,
    required this.end,
    this.effectiveBalance = 0.0,
    this.projectedBalance = 0.0,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<dynamic>? transactions,
    List<Account>? accounts,
    Account? selectedAccount,
    DateTime? start,
    DateTime? end,
    double? effectiveBalance,
    double? projectedBalance,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      start: start ?? this.start,
      end: end ?? this.end,
      effectiveBalance: effectiveBalance ?? this.effectiveBalance,
      projectedBalance: projectedBalance ?? this.projectedBalance,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  // Method to explicitly clear selected account
  DashboardState copyWithClearAccount({
    List<dynamic>? transactions,
    List<Account>? accounts,
    DateTime? start,
    DateTime? end,
    double? effectiveBalance,
    double? projectedBalance,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      selectedAccount: null,
      start: start ?? this.start,
      end: end ?? this.end,
      effectiveBalance: effectiveBalance ?? this.effectiveBalance,
      projectedBalance: projectedBalance ?? this.projectedBalance,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  final TransactionRepository _transactionRepo;
  final Ref _ref;

  DashboardController(this._transactionRepo, this._ref)
    : super(
        DashboardState(
          transactions: [],
          start: DateTime.now(),
          end: DateTime.now(),
        ),
      ) {
    _loadData(); // Initial load
  }

  Future<void> _loadData({bool refreshAccounts = true}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      List<Account> currentAccounts = state.accounts;

      // 0. Load Accounts if needed
      if (refreshAccounts) {
        final accountRepo = _ref.read(accountRepositoryProvider);
        currentAccounts = await accountRepo.getAccounts();
        // Update state but keep using local variable for calculations to ensure consistency
        state = state.copyWith(accounts: currentAccounts);
      }

      // 1. Get Settings for fiscal day
      final settingsAsync = _ref.read(settingsControllerProvider);
      final int fiscalDay = settingsAsync.value ?? 1;

      // 2. Calculate Rolling Month
      final now = DateTime.now();
      DateTime start, end;

      if (now.day >= fiscalDay) {
        // Current month period
        start = DateTime(now.year, now.month, fiscalDay);
        // End is next month start day - 1 second
        final nextMonthStart = DateTime(now.year, now.month + 1, fiscalDay);
        end = nextMonthStart.subtract(const Duration(seconds: 1));
      } else {
        // Previous month period
        start = DateTime(now.year, now.month - 1, fiscalDay);
        final currentMonthStart = DateTime(now.year, now.month, fiscalDay);
        end = currentMonthStart.subtract(const Duration(seconds: 1));
      }

      // 3. Fetch Transactions (for the list view, current month)
      final transactions = await _transactionRepo.getTransactions(
        start: start,
        end: end,
        accountId: state.selectedAccount?.id,
      );

      // 3b. Fetch Overdue Projected Transactions (Projected but date is BEFORE start)
      final overdueTransactions = await _transactionRepo
          .getOverdueProjectedTransactions(
            beforeDate: start,
            accountId: state.selectedAccount?.id,
          );

      // Combine lists: Overdue first, then current period
      // Note: effective transactions from previous months are NOT fetched (as per design), only overdue projected.
      final allTransactions = [...overdueTransactions, ...transactions];

      // 4. Calculate Balances
      // Initial Balance (Always part of Effective)
      double initialBalance = 0;
      if (state.selectedAccount != null) {
        initialBalance = state.selectedAccount!.initialBalance;
      } else {
        // Only sum accounts that are currently loaded
        initialBalance = currentAccounts.fold(
          0,
          (sum, account) => sum + account.initialBalance,
        );
      }

      // Effective Balance (Real transactions only)
      final effectiveTransactionBalance = await _transactionRepo.getBalance(
        accountId: state.selectedAccount?.id,
        status: 'effective',
      );
      final effectiveBalance = initialBalance + effectiveTransactionBalance;

      // Projected Balance (Effective + Projected up to end of period)
      // Note: We only include projected transactions that are WITHIN the current view period (or all future?)
      // User said: "forecast balance at the deadline date indicated on the account".
      // Let's assume "deadline date" = end of current rolling month (state.end).
      final projectedTransactionBalance = await _transactionRepo.getBalance(
        accountId: state.selectedAccount?.id,
        status: 'projected',
        maxDate: end, // Include projected up to the end of the month
      );

      final projectedBalance = effectiveBalance + projectedTransactionBalance;

      state = state.copyWith(
        transactions: allTransactions,
        start: start,
        end: end,
        effectiveBalance: effectiveBalance,
        projectedBalance: projectedBalance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      // In production, log stack trace
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }

  void selectAccount(Account? account) {
    if (account == null) {
      state = state.copyWithClearAccount(isLoading: true);
    } else {
      state = state.copyWith(selectedAccount: account, isLoading: true);
    }
    _loadData(refreshAccounts: false);
  }

  Future<void> processInbox() async {
    try {
      state = state.copyWith(isLoading: true);
      final inboxService = _ref.read(inboxServiceProvider);
      final count = await inboxService.processPendingItems();

      // If items were processed, reload data
      if (count > 0) {
        await _loadData(refreshAccounts: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      final transactionRepo = ref.watch(transactionRepositoryProvider);

      // Watch settings to trigger rebuild/reload when fiscal day changes
      ref.watch(settingsControllerProvider);
      // Watch account controller state to rebuild/reload when accounts change
      ref.watch(accountControllerProvider);

      return DashboardController(transactionRepo, ref);
    });
