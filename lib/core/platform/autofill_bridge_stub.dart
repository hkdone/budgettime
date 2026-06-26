/// Pont autofill natif (no-op hors Web).
class AutofillBridge {
  static ({String username, String password})? peek() => null;

  static void clear() {}
}
