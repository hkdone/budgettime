import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/settings_repository.dart';
import '../domain/app_settings.dart';
import '../data/settings_repository_impl.dart';
import '../../../core/services/database_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.read(databaseServiceProvider));
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSettings>>((ref) {
      return SettingsController(ref.read(settingsRepositoryProvider));
    });

class SettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsRepository _repository;

  SettingsController(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repository.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateFiscalDayStart(int day) async {
    final currentSettings = state.asData?.value ?? AppSettings();
    final newSettings = currentSettings.copyWith(fiscalDayStart: day);
    await _saveSettings(newSettings);
  }

  Future<void> toggleParser(String key, bool enabled) async {
    final currentSettings = state.asData?.value ?? AppSettings();
    final newParsers = Map<String, bool>.from(currentSettings.activeParsers);
    newParsers[key] = enabled;
    final newSettings = currentSettings.copyWith(activeParsers: newParsers);
    await _saveSettings(newSettings);
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      await _repository.saveSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
