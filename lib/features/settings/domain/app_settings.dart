class AppSettings {
  final int fiscalDayStart;
  final Map<String, bool> activeParsers;

  AppSettings({
    this.fiscalDayStart = 1,
    this.activeParsers = const {
      'la_banque_postale': true,
      'credit_mutuel': true,
    },
  });

  AppSettings copyWith({
    int? fiscalDayStart,
    Map<String, bool>? activeParsers,
  }) {
    return AppSettings(
      fiscalDayStart: fiscalDayStart ?? this.fiscalDayStart,
      activeParsers: activeParsers ?? this.activeParsers,
    );
  }
}
