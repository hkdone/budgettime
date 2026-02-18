import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database_service.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../data/account_repository_impl.dart';

class AccountController extends StateNotifier<AsyncValue<List<Account>>> {
  final AccountRepository _repository;
  final String? _userId;

  AccountController(this._repository, this._userId)
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
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createAccount({
        'name': name,
        'type': type,
        'initial_balance': initialBalance,
        'currency': 'EUR',
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
      final userId = DatabaseService().userId;
      return AccountController(repository, userId);
    });
