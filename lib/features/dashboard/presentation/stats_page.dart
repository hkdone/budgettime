import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'stats_controller.dart';
import '../../../core/utils/formatters.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _buildSectionTitle('Dépenses par Catégorie'),
                  _buildDataList(state.expenseByCategory, Colors.red),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Dépenses par Membre'),
                  _buildDataList(state.expenseByMember, Colors.orange),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Revenus par Catégorie'),
                  _buildDataList(state.incomeByCategory, Colors.green),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Revenus par Membre'),
                  _buildDataList(state.incomeByMember, Colors.teal),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(StatsState state) {
    final totalIncome = state.incomeByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final totalExpense = state.expenseByCategory.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final balance = totalIncome - totalExpense;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Cumul Annuel ${state.selectedYear}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              formatCurrency(balance),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.black : Colors.red,
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleSummaryItem('Revenus', totalIncome, Colors.green),
                _buildSimpleSummaryItem('Dépenses', totalExpense, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDataList(Map<String, double> data, Color color) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
      );
    }

    final sortedList = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sortedList.first.value;

    return Column(
      children: sortedList.map((entry) {
        final percentage = (entry.value / maxVal).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    formatCurrency(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withValues(alpha: 0.1),
                  color: color,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
