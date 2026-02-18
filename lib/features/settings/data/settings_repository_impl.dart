import '../../../core/services/database_service.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseService _dbService;

  SettingsRepositoryImpl(this._dbService);

  @override
  Future<int> getFiscalDayStart() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return 1;

    try {
      final records = await _dbService.pb
          .collection('settings')
          .getList(filter: 'user = "${user.id}"');

      if (records.items.isNotEmpty) {
        return records.items.first.data['fiscal_day_start'] ?? 1;
      }
    } catch (e) {
      // settings might not exist yet
    }
    return 1;
  }

  @override
  Future<void> setFiscalDayStart(int day) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    try {
      final records = await _dbService.pb
          .collection('settings')
          .getList(filter: 'user = "${user.id}"');

      if (records.items.isNotEmpty) {
        await _dbService.pb
            .collection('settings')
            .update(records.items.first.id, body: {'fiscal_day_start': day});
      } else {
        await _dbService.pb
            .collection('settings')
            .create(body: {'user': user.id, 'fiscal_day_start': day});
      }
    } catch (e) {
      rethrow;
    }
  }
}
