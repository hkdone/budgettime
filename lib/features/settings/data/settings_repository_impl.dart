import 'dart:convert';
import '../../../core/services/database_service.dart';
import '../domain/settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseService _dbService;

  SettingsRepositoryImpl(this._dbService);

  @override
  Future<AppSettings> getSettings() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return AppSettings();

    try {
      final records = await _dbService.pb
          .collection('settings')
          .getList(filter: 'user = "${user.id}"');

      if (records.items.isNotEmpty) {
        final data = records.items.first.data;
        final fiscalDay = data['fiscal_day_start'] ?? 1;

        final parsers = {'la_banque_postale': true, 'credit_mutuel': true};

        if (data['active_parsers'] != null) {
          final Map<String, dynamic> saved = data['active_parsers'] is String
              ? jsonDecode(data['active_parsers'])
              : data['active_parsers'];
          saved.forEach((key, value) {
            if (value is bool) parsers[key] = value;
          });
        }

        return AppSettings(fiscalDayStart: fiscalDay, activeParsers: parsers);
      }
    } catch (e) {
      // settings might not exist yet
    }
    return AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return;

    final body = {
      'user': user.id,
      'fiscal_day_start': settings.fiscalDayStart,
      'active_parsers': settings.activeParsers,
    };

    try {
      final records = await _dbService.pb
          .collection('settings')
          .getList(filter: 'user = "${user.id}"');

      if (records.items.isNotEmpty) {
        await _dbService.pb
            .collection('settings')
            .update(records.items.first.id, body: body);
      } else {
        await _dbService.pb.collection('settings').create(body: body);
      }
    } catch (e) {
      rethrow;
    }
  }
}
