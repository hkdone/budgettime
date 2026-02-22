import '../inbox_processing_strategy.dart';

class CreditMutuelSmsParser implements InboxProcessingStrategy {
  // Example SMS: "CM: Achat CB 25,00 EUR le 21/02 a RESTO LYON"
  final RegExp _pattern = RegExp(
    r'CM:.*?Achat CB.*?(\d+[.,]\d{2})\s?EUR.*?le.*?a\s?(.*)',
    caseSensitive: false,
  );

  @override
  double canHandle(Map<String, dynamic> item) {
    final content = item['content'] as String? ?? '';
    return (content.contains('CM:') && content.contains('Achat')) ? 1.0 : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final content = item['content'] as String;
    final match = _pattern.firstMatch(content);

    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '.') ?? '0.0';
      final label = match.group(2)?.trim() ?? 'CM Achat';

      return {
        'amount': -(double.tryParse(amountStr) ?? 0.0),
        'label': label,
        'type': 'expense',
        'date': DateTime.now().toIso8601String(),
        'category': 'Autre',
      };
    }
    return null;
  }
}
