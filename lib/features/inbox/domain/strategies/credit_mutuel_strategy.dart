import '../inbox_processing_strategy.dart';

class CreditMutuelSmsParser implements InboxProcessingStrategy {
  // Example 1 (Purchase): "CM: Achat CB 25,00 EUR le 21/02 a RESTO LYON"
  // Example 2 (Statement): "Crédit Mutuel : 23/02 Cpt: XXX90101 Solde=+1 646,41 EUR - Opération créditrice 100,00 EUR (VIR INST WERO MME FABIENNE BRIAN)."
  final RegExp _patternAchat = RegExp(
    r'CM:.*?Achat CB.*?(\d+[.,]\d{2})\s?EUR.*?le.*?a\s?(.*)',
    caseSensitive: false,
  );

  final RegExp _patternStatement = RegExp(
    r'(?:Crédit Mutuel|CM)\s?:.*?Opération\s+(créditrice|débitrice)\s+(\d+[.,]\d{2})\s?EUR\s*\((.*)\)',
    caseSensitive: false,
  );

  @override
  double canHandle(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';
    final isCM = payload.contains('CM:') || payload.contains('Crédit Mutuel');
    final hasKeywords =
        payload.contains('Achat') ||
        payload.contains('Opération') ||
        payload.contains('EUR');

    return (isCM && hasKeywords) ? 1.0 : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';

    // Try Statement pattern first (richer)
    final statementMatch = _patternStatement.firstMatch(payload);
    if (statementMatch != null) {
      final typeStr = statementMatch.group(1)?.toLowerCase() ?? 'débitrice';
      final amountStr = statementMatch.group(2)?.replaceAll(',', '.') ?? '0.0';
      final label = statementMatch.group(3)?.trim() ?? 'CM Opération';

      final isCredit = typeStr.contains('crédit');
      final amount = double.tryParse(amountStr) ?? 0.0;

      return {
        'amount': isCredit ? amount : -amount,
        'label': label,
        'type': isCredit ? 'income' : 'expense',
        'date': DateTime.now().toIso8601String(),
        'category': 'Autre',
      };
    }

    // Fallback to Achat pattern
    final achatMatch = _patternAchat.firstMatch(payload);
    if (achatMatch != null) {
      final amountStr = achatMatch.group(1)?.replaceAll(',', '.') ?? '0.0';
      final label = achatMatch.group(2)?.trim() ?? 'CM Achat';

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
