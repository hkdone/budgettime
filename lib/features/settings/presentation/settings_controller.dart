import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import '../data/settings_repository_impl.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.read(databaseServiceProvider));
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<int>>((ref) {
      return SettingsController(ref.read(settingsRepositoryProvider));
    });

class SettingsController extends StateNotifier<AsyncValue<int>> {
  final SettingsRepository _repository;

  SettingsController(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final day = await _repository.getFiscalDayStart();
      state = AsyncValue.data(day);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateFiscalDayStart(int day) async {
    try {
      await _repository.setFiscalDayStart(day);
      state = AsyncValue.data(day);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
