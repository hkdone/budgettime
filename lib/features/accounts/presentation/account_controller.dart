import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/start_app.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../data/account_repository_impl.dart';
import '../../transactions/domain/transaction_repository.dart';

class AccountController extends StateNotifier<AsyncValue<List<Account>>> {
  final AccountRepository _repository;
  final TransactionRepository _transactionRepository;
  final String? _userId;

  AccountController(this._repository, this._transactionRepository, this._userId)
    : super(const AsyncValue.loading()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    if (_userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAccounts());
  }

  Future<void> addAccount(
    String name,
    String type,
    double initialBalance,
    String? externalId,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final account = await _repository.createAccount({
        'name': name,
        'type': type,
        'initial_balance': initialBalance, // Legacy keep
        'currency': 'EUR',
        'external_id': externalId,
      });

      // Create Initial Anchor Transaction
      await _transactionRepository.addTransaction({
        'amount': 0,
        'label': 'Solde Initial',
        'type': 'income',
        'date': DateTime.now(),
        'account': account.id,
        'status': 'effective',
        'is_automatic': true,
        'bank_balance': initialBalance,
        'category': 'Ajustement',
      });

      return _repository.getAccounts();
    });
  }

  Future<void> updateAccount(
    String id,
    String name,
    String type,
    double initialBalance,
    String? externalId,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateAccount(id, {
        'name': name,
        'type': type,
        'external_id': externalId,
        'initial_balance': initialBalance, // Legacy keep
      });

      // Create Update Anchor Transaction
      await _transactionRepository.addTransaction({
        'amount': 0,
        'label': 'Mise à jour solde',
        'type': 'income',
        'date': DateTime.now(),
        'account': id,
        'status': 'effective',
        'is_automatic': true,
        'bank_balance': initialBalance,
        'category': 'Ajustement',
      });

      return _repository.getAccounts();
    });
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    await AsyncValue.guard(() async {
      await _repository.deleteAccount(id);
      await loadAccounts();
    });
  }
}

final accountControllerProvider =
    StateNotifierProvider<AccountController, AsyncValue<List<Account>>>((ref) {
      final repository = ref.watch(accountRepositoryProvider);
      final transactionRepository = ref.watch(transactionRepositoryProvider);
      final userId = DatabaseService().userId;
      return AccountController(repository, transactionRepository, userId);
    });

final accountBalanceProvider = FutureProvider.family<double, Account>((
  ref,
  account,
) async {
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  // getBalance is now absolute (it handles anchor logic)
  return transactionRepo.getBalance(accountId: account.id);
});
