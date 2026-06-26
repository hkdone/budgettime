import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_theme.dart';
import 'widgets/statistics_widgets.dart';

class StatsTrendPage extends ConsumerStatefulWidget {
  const StatsTrendPage({super.key});

  @override
  ConsumerState<StatsTrendPage> createState() => _StatsTrendPageState();
}

class _StatsTrendPageState extends ConsumerState<StatsTrendPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tendances historiques')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Par année')),
                      ButtonSegment(value: 1, label: Text('Par mois')),
                    ],
                    selected: {_tabIndex},
                    onSelectionChanged: (v) => setState(() => _tabIndex = v.first),
                  ),
                ),
                Expanded(
                  child: _tabIndex == 0
                      ? _buildYearlyTab(state)
                      : _buildMonthlyTab(state),
                ),
              ],
            ),
    );
  }

  Widget _buildYearlyTab(StatsState state) {
    if (state.yearlyTrends.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final yearlyAsMonthly = state.yearlyTrends
        .map(
          (t) => MonthlyStats(
            month: DateTime(t.year, 1, 1),
            income: t.income,
            expense: t.expense,
          ),
        )
        .toList();

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(statsControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Historique — Reste à vivre annuel',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Revenus − Dépenses (hors virements)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SignedYearlyBarChart(
            trends: yearlyAsMonthly,
            title: '6 dernières années',
          ),
          const SizedBox(height: 24),
          const Text(
            'Détail par année',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...state.yearlyTrends.asMap().entries.map((entry) {
            final index = entry.key;
            final trend = entry.value;
            final previous = index > 0 ? state.yearlyTrends[index - 1] : null;
            return _buildYearlyCard(trend, previous);
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab(StatsState state) {
    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(statsControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mois par mois — ${state.selectedYear}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          MonthlyBalanceBarChart(
            months: state.monthlyTrendsForYear,
          ),
          const SizedBox(height: 24),
          ...state.monthlyTrendsForYear.map((m) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${m.month.month}/${m.month.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '+${formatCurrency(m.income)}  ·  -${formatCurrency(m.expense)}',
                ),
                trailing: Text(
                  formatCurrency(m.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.balance >= 0
                        ? AppColors.chartIncome
                        : AppColors.chartExpense,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                  const SizedBox(height: 4),
                  Text(
                    '+${formatCurrency(trend.income)}  ·  -${formatCurrency(trend.expense)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
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
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'vs année précédente',
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
