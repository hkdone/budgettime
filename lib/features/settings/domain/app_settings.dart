class AppSettings {
  final int fiscalDayStart;

  AppSettings({this.fiscalDayStart = 1});

  AppSettings copyWith({int? fiscalDayStart}) {
    return AppSettings(fiscalDayStart: fiscalDayStart ?? this.fiscalDayStart);
  }
}
