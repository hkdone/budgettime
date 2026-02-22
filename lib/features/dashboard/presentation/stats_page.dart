import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';

import 'package:fl_chart/fl_chart.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  String _viewType = 'projected'; // 'real' or 'projected'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsControllerProvider);
    final controller = ref.read(statsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques Annuelles'),
        actions: [
          DropdownButton<int>(
            value: state.selectedYear,
            underline: const SizedBox(),
            onChanged: (year) {
              if (year != null) controller.changeYear(year);
            },
            items: List.generate(5, (index) => DateTime.now().year - index)
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  ),
                )
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.trending_up, color: Colors.blueAccent),
            tooltip: 'Tendances Annuelles',
            onPressed: () {
              context.push('/stats-trend');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(state),
                  const SizedBox(height: 24),
                  Center(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'real',
                          label: Text('Réel'),
                          icon: Icon(Icons.account_balance_wallet),
                        ),
                        ButtonSegment(
                          value: 'projected',
                          label: Text('Prévisionnel'),
                          icon: Icon(Icons.event_note),
                        ),
                      ],
                      selected: {_viewType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _viewType = newSelection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Dépenses par Catégorie'),
                  _buildPieChart(
                    _viewType == 'real'
                        ? state.realExpenseByCategory
                        : state.projectedExpenseByCategory,
                    Colors.redAccent,
                  ),
                  const SizedBox(height: 48),
                  _buildSectionTitle('Revenus par Membre'),
                  _buildPieChart(
                    _viewType == 'real'
                        ? state.realIncomeByMember
                        : state.projectedIncomeByMember,
                    Colors.teal,
                  ),
                  const SizedBox(height: 48),
                  _buildSectionTitle('Dépenses par Membre (Prévisionnel)'),
                  _buildPieChart(
                    state.projectedExpenseByMember,
                    Colors.orangeAccent,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(StatsState state) {
    final realIncome = state.realIncomeByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final realExpense = state.realExpenseByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final realBalance = realIncome - realExpense;

    final projectedIncome = state.projectedIncomeByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final projectedExpense = state.projectedExpenseByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final projectedBalance = projectedIncome - projectedExpense;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Bilan Annuel ${state.selectedYear}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    'Réel',
                    realBalance,
                    realIncome,
                    realExpense,
                    Colors.blueGrey,
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Prévisionnel',
                    projectedBalance,
                    projectedIncome,
                    projectedExpense,
                    Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    double balance,
    double income,
    double expense,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          formatCurrency(balance),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: balance >= 0 ? Colors.black : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward, size: 12, color: Colors.green),
            Text(
              formatCurrency(income),
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_downward, size: 12, color: Colors.red),
            Text(
              formatCurrency(expense),
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data, Color baseColor) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Generate colors
    final List<Color> palette = [
      baseColor,
      baseColor.withValues(alpha: 0.8),
      baseColor.withValues(alpha: 0.6),
      baseColor.withValues(alpha: 0.4),
      baseColor.withValues(alpha: 0.2),
      ...Colors.primaries.map((c) => c.withValues(alpha: 0.5)),
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sortedEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final val = entry.value;
                final percentage = (val.value / total) * 100;

                return PieChartSectionData(
                  color: palette[index % palette.length],
                  value: val.value,
                  title: percentage > 5
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: sortedEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final val = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette[index % palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${val.key}: ${formatCurrency(val.value)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
