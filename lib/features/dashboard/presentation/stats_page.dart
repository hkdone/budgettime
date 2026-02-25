import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/domain/categories.dart';

import 'package:fl_chart/fl_chart.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  String _viewMode = 'projected'; // 'real' or 'projected'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsControllerProvider);

    return state.isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            appBar: AppBar(
              title: const Text('Analyse Annuelle'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/stats-trend'),
                  icon: const Icon(Icons.show_chart),
                  tooltip: 'Tendances pluriannuelles',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<int>(
                    value: state.selectedYear,
                    onChanged: (y) {
                      if (y != null) {
                        ref
                            .read(statsControllerProvider.notifier)
                            .changeYear(y);
                      }
                    },
                    items: [for (int i = 0; i < 6; i++) DateTime.now().year + i]
                        .map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(statsControllerProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildGlobalSummary(state),
                    if (state.statsByAccount.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text('Aucune donnée pour cette année'),
                        ),
                      )
                    else
                      ...state.statsByAccount.entries.map((entry) {
                        final accountId = entry.key;
                        final stats = entry.value;
                        final accountName =
                            state.accountNames[accountId] ?? 'Compte';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    accountName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(indent: 16, endIndent: 16),

                            // Dual View: Category Expenses (Real vs Projected)
                            _buildSectionTitle('Dépenses par Catégorie'),
                            _buildDualCharts(
                              realData: stats.realExpenseByCategory,
                              projectedData: stats.projectedExpenseByCategory,
                              viewMode: _viewMode,
                              baseColor: Colors.redAccent,
                            ),

                            // Dual View: Member Income (Real vs Projected)
                            _buildSectionTitle('Revenus par Membre'),
                            _buildDualCharts(
                              realData: stats.realIncomeByMember,
                              projectedData: stats.projectedIncomeByMember,
                              viewMode: _viewMode,
                              baseColor: Colors.teal,
                            ),

                            // Single View: Member Expenses (Projected)
                            _buildSectionTitle(
                              'Dépenses par Membre (Prévisionnel)',
                            ),
                            Center(
                              child: SizedBox(
                                width: 500,
                                child: _buildPieChart(
                                  stats.projectedExpenseByMember,
                                  Colors.orangeAccent,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomAppBar(
              height: 70,
              child: Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'real',
                      label: Text('Réel'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'projected',
                      label: Text('Prévisionnel'),
                      icon: Icon(Icons.event_available),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (val) {
                    setState(() {
                      _viewMode = val.first;
                    });
                  },
                ),
              ),
            ),
          );
  }

  Widget _buildGlobalSummary(StatsState state) {
    double totalRealIncome = 0;
    double totalRealExpense = 0;
    double totalProjectedIncome = 0;
    double totalProjectedExpense = 0;

    for (final stats in state.statsByAccount.values) {
      // Helper to sum excluding transfers
      double sumSafe(Map<String, double> map) {
        return map.entries
            .where((e) => e.key != 'transfer')
            .fold(0.0, (a, b) => a + b.value);
      }

      totalRealIncome += sumSafe(stats.realIncomeByCategory);
      totalRealExpense += sumSafe(stats.realExpenseByCategory);
      totalProjectedIncome += sumSafe(stats.projectedIncomeByCategory);
      totalProjectedExpense += sumSafe(stats.projectedExpenseByCategory);
    }

    final realBalance = totalRealIncome - totalRealExpense;
    final projectedBalance = totalProjectedIncome - totalProjectedExpense;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Bilan Global ${state.selectedYear}',
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
                    totalRealIncome,
                    totalRealExpense,
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
                    totalProjectedIncome,
                    totalProjectedExpense,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDualCharts({
    required Map<String, double> realData,
    required Map<String, double> projectedData,
    required String viewMode,
    required Color baseColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildPieChart(realData, baseColor, title: 'Réel'),
              ),
              Expanded(
                child: _buildPieChart(
                  projectedData,
                  baseColor,
                  title: 'Prévisionnel',
                ),
              ),
            ],
          );
        } else {
          return Center(
            child: SizedBox(
              width: 500,
              child: _buildPieChart(
                viewMode == 'real' ? realData : projectedData,
                baseColor,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPieChart(
    Map<String, double> data,
    Color baseColor, {
    String? title,
  }) {
    final state = ref.read(statsControllerProvider);
    if (data.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              const Text(
                'Aucune donnée',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: sortedEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final val = entry.value;
                final percentage = (val.value / total) * 100;

                return PieChartSectionData(
                  color: palette[index % palette.length],
                  value: val.value,
                  title: percentage > 10
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  radius: 45,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: sortedEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final val = entry.value;

              // Map ID to Name
              String displayName = val.key;
              if (state.memberNames.containsKey(val.key)) {
                displayName = state.memberNames[val.key]!;
              } else if (state.categoryNames.containsKey(val.key)) {
                displayName = state.categoryNames[val.key]!;
              } else {
                // Try to find in global categories list
                try {
                  displayName = kTransactionCategories
                      .firstWhere((c) => c.id == val.key)
                      .name;
                } catch (_) {
                  // Fallback to name-cased ID if it's the old 'Recurrence' string
                  if (val.key == 'Recurrence') {
                    displayName = 'Récurrence';
                  }
                }
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette[index % palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$displayName: ${formatCurrency(val.value)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
