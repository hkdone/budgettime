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

        // Lire auto_sync et pull_to_sync depuis le champ JSON active_parsers
        bool autoSync = true;
        bool pullToSync = false;
        try {
          final raw = data['active_parsers'];
          final Map<String, dynamic> parsed = raw is String
              ? jsonDecode(raw)
              : (raw as Map<String, dynamic>? ?? {});
          if (parsed.containsKey('auto_sync')) {
            autoSync = parsed['auto_sync'] as bool? ?? true;
          }
          if (parsed.containsKey('pull_to_sync')) {
            pullToSync = parsed['pull_to_sync'] as bool? ?? false;
          }
        } catch (_) {}

        return AppSettings(
          fiscalDayStart: fiscalDay,
          autoSync: autoSync,
          pullToSync: pullToSync,
        );
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

    final body = {'user': user.id, 'fiscal_day_start': settings.fiscalDayStart};

    // Lire les active_parsers existants pour ne pas écraser les autres valeurs
    Map<String, dynamic> activeParsers = {};
    try {
      final existing = await _dbService.pb
          .collection('settings')
          .getList(filter: 'user = "${user.id}"');
      if (existing.items.isNotEmpty) {
        final raw = existing.items.first.data['active_parsers'];
        activeParsers = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : (raw as Map<String, dynamic>? ?? {});
      }
    } catch (_) {}

    activeParsers['auto_sync'] = settings.autoSync;
    activeParsers['pull_to_sync'] = settings.pullToSync;
    body['active_parsers'] = jsonEncode(activeParsers);

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
