import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';

class StatsTrendPage extends ConsumerWidget {
  const StatsTrendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tendances Annuelles')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.yearlyTrends.isEmpty
          ? const Center(child: Text('Aucune donnée disponible'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Évolution du Reste à Vivre',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cumul annuel (Revenus - Dépenses)',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: _buildTrendChart(state.yearlyTrends)),
                  const SizedBox(height: 24),
                  const Text(
                    'Détails par année',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: state.yearlyTrends.length,
                      itemBuilder: (context, index) {
                        final trend = state.yearlyTrends[index];

                        YearlyTrend? previousTrend;
                        if (index > 0) {
                          previousTrend = state.yearlyTrends[index - 1];
                        }

                        return _buildYearlyCard(trend, previousTrend);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTrendChart(List<YearlyTrend> trends) {
    if (trends.isEmpty) return const SizedBox();

    final maxBalance = trends
        .map((e) => e.balance.abs())
        .reduce((a, b) => a > b ? a : b);
    final chartMax = maxBalance == 0 ? 100.0 : maxBalance * 1.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight > 0
            ? constraints.maxHeight
            : 250.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: trends.map((trend) {
            final heightFactor = (trend.balance.abs() / chartMax).clamp(
              0.05,
              1.0,
            );
            final isPositive = trend.balance >= 0;

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${(trend.balance / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: (chartHeight - 40) * heightFactor,
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withValues(alpha: 0.7)
                          : Colors.red.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trend.year.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildYearlyCard(YearlyTrend trend, YearlyTrend? previous) {
    double? percentChange;
    if (previous != null && previous.balance != 0) {
      percentChange =
          ((trend.balance - previous.balance) / previous.balance.abs()) * 100;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.year.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Solde: ${formatCurrency(trend.balance)}',
                  style: TextStyle(
                    color: trend.balance >= 0
                        ? Colors.green[700]
                        : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (percentChange != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        percentChange >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: percentChange >= 0 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: percentChange >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'vs l\'an dernier',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
