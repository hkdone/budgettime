import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../../core/services/database_service.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final DatabaseService _dbService;

  AccountRepositoryImpl(this._dbService);

  @override
  Future<List<Account>> getAccounts() async {
    final user = _dbService.userId;
    if (user == null) return [];

    final records = await _dbService.pb
        .collection('accounts')
        .getFullList(sort: 'created', filter: 'user = "$user"');

    return records.map((record) => Account.fromRecord(record)).toList();
  }

  @override
  Future<Account> createAccount(Map<String, dynamic> data) async {
    final user = _dbService.userId;
    if (user == null) throw Exception('User not authenticated');

    final body = {...data, 'user': user};

    try {
      final record = await _dbService.pb
          .collection('accounts')
          .create(body: body);
      return Account.fromRecord(record);
    } on ClientException catch (e) {
      // Log the full response for debugging
      throw Exception('Failed to create account: ${e.response}');
    }
  }

  @override
  Future<Account> updateAccount(String id, Map<String, dynamic> data) async {
    final record = await _dbService.pb
        .collection('accounts')
        .update(id, body: data);
    return Account.fromRecord(record);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _dbService.pb.collection('accounts').delete(id);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(DatabaseService());
});
