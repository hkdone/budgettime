class AppSettings {
  final int fiscalDayStart;
  final bool autoSync;
  final bool pullToSync;

  AppSettings({
    this.fiscalDayStart = 1,
    this.autoSync = true,
    this.pullToSync = false,
  });

  AppSettings copyWith({
    int? fiscalDayStart,
    bool? autoSync,
    bool? pullToSync,
  }) {
    return AppSettings(
      fiscalDayStart: fiscalDayStart ?? this.fiscalDayStart,
      autoSync: autoSync ?? this.autoSync,
      pullToSync: pullToSync ?? this.pullToSync,
    );
  }
}
