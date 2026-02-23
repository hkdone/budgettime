import '../inbox_processing_strategy.dart';

class LaBanquePostaleSmsParser implements InboxProcessingStrategy {
  // Example SMS: "LBP: Paiement de 15,30 EUR chez CARREFOUR le 22/02/2026."
  final RegExp _pattern = RegExp(
    r'LBP:.*?Paiement.*?(\d+[.,]\d{2})\s?EUR\s?chez\s?(.*?)\s?le',
    caseSensitive: false,
  );

  @override
  double canHandle(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';
    return (payload.contains('LBP:') && payload.contains('Paiement'))
        ? 1.0
        : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';
    final match = _pattern.firstMatch(payload);

    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '.') ?? '0.0';
      final label = match.group(2)?.trim() ?? 'LBP Paiement';

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

class LaBanquePostaleAppParser implements InboxProcessingStrategy {
  // Example JSON from App Notification: {"type": "LBP_APP", "amount": 42.50, "merchant": "Amazon"}
  @override
  double canHandle(Map<String, dynamic> item) {
    final metadata = item['metadata'] as Map<String, dynamic>?;
    return (metadata != null && metadata['type'] == 'LBP_APP') ? 1.0 : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final metadata = item['metadata'] as Map<String, dynamic>;
    return {
      'amount': -(metadata['amount'] as num).toDouble(),
      'label': metadata['merchant'] ?? 'LBP App Notification',
      'type': 'expense',
      'date': DateTime.now().toIso8601String(),
      'category': 'Autre',
    };
  }
}
