import 'account.dart';

abstract class AccountRepository {
  Future<List<Account>> getAccounts();
  Future<Account> createAccount(Map<String, dynamic> data);
  Future<Account> updateAccount(String id, Map<String, dynamic> data);
  Future<void> deleteAccount(String id);
}
