import '../inbox_processing_strategy.dart';

class DefaultRegexStrategy implements InboxProcessingStrategy {
  // Example Pattern: "Virement de 50.00 EUR le 12/02/2026"
  // This is a simplified regex for demo purposes.
  // In production, you'd have a list of regexes or more complex logic.

  // "Virement" or "Paiement" followed by amount
  final RegExp _pattern = RegExp(
    r'(Virement|Paiement|Débit).*?(\d+[.,]\d{2})\s?EUR',
    caseSensitive: false,
  );

  @override
  double canHandle(Map<String, dynamic> item) {
    final content = item['content'] as String?;
    if (content == null) return 0.0;

    return _pattern.hasMatch(content) ? 0.9 : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final content = item['content'] as String;
    final match = _pattern.firstMatch(content);

    if (match != null) {
      final typeStr = match.group(1)?.toLowerCase() ?? '';
      final amountStr = match.group(2)?.replaceAll(',', '.') ?? '0.0';
      final amount = double.tryParse(amountStr) ?? 0.0;

      String type = 'expense';
      if (typeStr.contains('virement') && !typeStr.contains('emis')) {
        // Simple logic: "Virement" could be income depending on context,
        // often "Virement reçu" vs "Virement émis".
        // Let's assume generic logic for now.
        type = 'expense';
      }

      return {
        'amount': amount,
        'label': content.length > 50 ? content.substring(0, 50) : content,
        'type': type,
        'date': DateTime.now().toUtc().toString().split(
          '.',
        )[0], // Or extract date from text
        'category': 'Autre',
        'is_automatic': true,
      };
    }
    return null;
  }
}
