import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';
import '../application/month_stats_service.dart';
import 'widgets/statistics_widgets.dart';

/// Historique mensuel (6 mois) pour le mini-graphique du dashboard.
final monthlyHistoryProvider = FutureProvider.family<List<MonthlyStats>, String?>(
  (ref, accountId) async {
    final repo = ref.read(transactionRepositoryProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final transactions = await repo.getTransactions(
      start: start,
      end: end,
      accountId: accountId,
    );

    return MonthStatsService.monthlyHistory(
      allTransactions: transactions,
      accountId: accountId,
      months: 6,
    );
  },
);
