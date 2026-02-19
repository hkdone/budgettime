import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'statistics_controller.dart';
import '../../transactions/domain/categories.dart';
import '../../accounts/presentation/account_controller.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  DateTime _selectedMonth = DateTime.now();
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    // Defer loading to avoid build error
    Future.microtask(() => _loadData());
  }

  void _loadData() {
    ref
        .read(statisticsControllerProvider.notifier)
        .loadStats(targetMonth: _selectedMonth, accountId: _selectedAccountId);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statisticsControllerProvider);
    final accountsAsync = ref.watch(accountControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse'),
        actions: [
          // Account Selector
          accountsAsync.when(
            data: (accounts) => DropdownButton<String>(
              value: _selectedAccountId,
              hint: const Text('Tout', style: TextStyle(color: Colors.white)),
              dropdownColor: Colors.blueGrey,
              icon: const Icon(Icons.account_balance, color: Colors.white),
              underline: Container(),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tous les comptes'),
                ),
                ...accounts.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAccountId = value;
                });
                _loadData();
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Month Selector
            _buildMonthSelector(),
            const SizedBox(height: 24),

            statsAsync.when(
              data: (data) => Column(
                children: [
                  // Pie Chart
                  _buildPieChartSection(data),
                  const SizedBox(height: 32),
                  // Bar Chart
                  _buildBarChartSection(data),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erreur: $err')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  );
                });
                _loadData();
              },
            ),
            Text(
              DateFormat(
                'MMMM yyyy',
                'fr_FR',
              ).format(_selectedMonth).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month + 1,
                  );
                });
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(StatisticsData data) {
    if (data.expenseByCategory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucune dépense pour ce mois'),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Répartition des Dépenses (${data.totalExpense.toStringAsFixed(2)} €)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: data.expenseByCategory.map((catStat) {
                    final category = kTransactionCategories.firstWhere(
                      (c) => c.id == catStat.categoryId,
                      orElse: () => const Category(
                        id: 'unknown',
                        name: 'Inconnu',
                        icon: Icons.help,
                        color: Colors.grey,
                      ),
                    );
                    return PieChartSectionData(
                      color: category.color,
                      value: catStat.amount,
                      title: '${catStat.percentage.round()}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: data.expenseByCategory.take(5).map((catStat) {
                final category = kTransactionCategories.firstWhere(
                  (c) => c.id == catStat.categoryId,
                  orElse: () => const Category(
                    id: 'unknown',
                    name: 'Inconnu',
                    icon: Icons.help,
                    color: Colors.grey,
                  ),
                );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: category.color),
                    const SizedBox(width: 4),
                    Text(
                      '${category.name} (${catStat.amount.toStringAsFixed(0)}€)',
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartSection(StatisticsData data) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Évolution Revenus vs Dépenses (6 mois)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      data.history.fold(
                        0.0,
                        (max, e) =>
                            (e.income > e.expense ? e.income : e.expense) > max
                            ? (e.income > e.expense ? e.income : e.expense)
                            : max,
                      ) *
                      1.2, // +20% buffer
                  barTouchData: const BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < data.history.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat(
                                  'MMM',
                                ).format(data.history[value.toInt()].month),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ), // Hide Y axis for cleaner look
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: data.history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stats = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: stats.income,
                          color: Colors.green,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: stats.expense,
                          color: Colors.red,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
