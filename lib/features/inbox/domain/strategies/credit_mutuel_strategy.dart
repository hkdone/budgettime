import '../../../../core/utils/formatters.dart';
import '../inbox_processing_strategy.dart';

class CreditMutuelSmsParser implements InboxProcessingStrategy {
  // Example 1 (Purchase): "CM: Achat CB 25,00 EUR le 21/02 a RESTO LYON"
  // Example 2 (Statement): " 23/02 Cpt: XXX90101 Solde=+1 646,41 EUR - Opération créditrice 100,00 EUR (VIR INST WERO MME FABIENNE BRIAN)."
  final RegExp _patternAchat = RegExp(
    r'CM:.*?Achat CB.*?(\d+[.,]\d{2})\s?EUR.*?le.*?a\s?(.*)',
    caseSensitive: false,
  );

  final RegExp _patternCMPay = RegExp(
    r'Votre paiement de\s+([\d+.,]+)\s?€\s+pour\s+(.*?)\s+a bien été effectué',
    caseSensitive: false,
  );

  final RegExp _patternStatement = RegExp(
    r'(?:(\d{2}/\d{2})\s+)?.*?Cpt:\s*(\S+).*?Solde\s*=\s*([+-]?[\d\s,.]+)\s?EUR.*?Opération\s+(créditrice|débitrice)\s+(\d+[.,]\d{2})\s?EUR\s*\((.*)\)',
    caseSensitive: false,
  );

  @override
  double canHandle(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';
    final metadata = item['metadata'] as Map<String, dynamic>?;
    final package = metadata?['package']?.toString() ?? '';

    final isCM =
        payload.contains('CM:') ||
        payload.contains('Crédit Mutuel') ||
        payload.contains('Votre paiement de') ||
        package.contains('payment.app.cm') ||
        (payload.contains('Cpt:') && payload.contains('Solde='));

    final hasKeywords =
        payload.contains('Achat') ||
        payload.contains('Opération') ||
        payload.contains('paiement') ||
        payload.contains('EUR') ||
        payload.contains('€');

    return (isCM && hasKeywords) ? 1.0 : 0.0;
  }

  @override
  Map<String, dynamic>? extractTransactionData(Map<String, dynamic> item) {
    final payload = item['raw_payload'] as String? ?? '';

    // 1. Try CMPay (Notification App)
    final cmPayMatch = _patternCMPay.firstMatch(payload);
    if (cmPayMatch != null) {
      final amountStr = cmPayMatch.group(1)?.replaceAll(',', '.') ?? '0.0';
      final label = cmPayMatch.group(2)?.trim() ?? 'CM Pay';

      return {
        'amount': -(double.tryParse(amountStr) ?? 0.0),
        'label': label,
        'type': 'expense',
        'date': DateTime.now().toIso8601String(),
        'category': 'Autre',
        'status':
            'planned', // CM Pay notifications are for future/pending debit
        'is_automatic': true,
      };
    }

    // 2. Try Statement pattern (SMS rich)
    final statementMatch = _patternStatement.firstMatch(payload);
    if (statementMatch != null) {
      final dateStr = statementMatch.group(1); // Optional: "23/02"
      final externalId = statementMatch.group(2);
      final balanceStr = statementMatch.group(3) ?? '0.0';
      final typeStr = statementMatch.group(4)?.toLowerCase() ?? 'débitrice';
      final amountStr = statementMatch.group(5) ?? '0.0';
      final label = statementMatch.group(6)?.trim() ?? 'CM Opération';

      final isCredit = typeStr.contains('crédit');
      final amount = parseAmount(amountStr);
      final bankBalance = parseAmount(balanceStr);

      // Handle date if extracted (DD/MM format)
      DateTime transactionDate = DateTime.now();
      if (dateStr != null && dateStr.contains('/')) {
        try {
          final parts = dateStr.split('/');
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final now = DateTime.now();
          // Assume current year (or previous if month is later than now)
          int year = now.year;
          if (month > now.month) year--;
          transactionDate = DateTime(year, month, day);
        } catch (_) {}
      }

      return {
        'amount': isCredit ? amount : -amount,
        'label': label,
        'type': isCredit ? 'income' : 'expense',
        'date': formatDateForPb(transactionDate),
        'category': 'Autre',
        'account_external_id': externalId,
        'bank_balance': bankBalance,
        'status': 'effective', // Pre-select "Réel"
        'is_automatic': true,
      };
    }

    // 3. Fallback to Achat pattern (Classic SMS)
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
        'is_automatic': true,
      };
    }

    return null;
  }
}
