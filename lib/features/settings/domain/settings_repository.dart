abstract class SettingsRepository {
  Future<int> getFiscalDayStart();
  Future<void> setFiscalDayStart(int day);
}
