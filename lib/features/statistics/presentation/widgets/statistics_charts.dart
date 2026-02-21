import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../transactions/domain/categories.dart';
import '../statistics_controller.dart';
import '../../../members/domain/member.dart';
import 'package:budgettime/core/utils/formatters.dart';

class CategoryPieChart extends StatelessWidget {
  final List<CategoryStats> stats;
  final double totalAmount;
  final bool showLegend;

  const CategoryPieChart({
    super.key,
    required this.stats,
    required this.totalAmount,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: stats.map((catStat) {
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
                  title: stats.length <= 5
                      ? '${catStat.percentage.round()}%'
                      : '',
                  radius: 40,
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
        if (showLegend) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: stats.take(5).map((catStat) {
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
                  Container(width: 8, height: 8, color: category.color),
                  const SizedBox(width: 4),
                  Text(
                    '${category.name} (${catStat.amount.toStringAsFixed(0)}€)',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class MemberPieChart extends StatelessWidget {
  final List<MemberStats> stats;
  final List<Member> members;
  final double totalAmount;
  final String title;
  final bool showLegend;

  const MemberPieChart({
    super.key,
    required this.stats,
    required this.members,
    required this.totalAmount,
    required this.title,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty || totalAmount == 0) return const SizedBox.shrink();

    return Column(
      children: [
        if (showLegend)
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: stats.map((stat) {
                Color memberColor = Colors.grey;
                if (stat.memberId != 'common') {
                  final member = members.firstWhere(
                    (m) => m.id == stat.memberId,
                    orElse: () => const Member(
                      id: 'unknown',
                      name: 'Inconnu',
                      icon: Icons.help,
                    ),
                  );
                  memberColor =
                      Colors.primaries[member.name.hashCode %
                          Colors.primaries.length];
                }
                return PieChartSectionData(
                  color: memberColor,
                  value: stat.amount,
                  title: stats.length <= 3 ? '${stat.percentage.round()}%' : '',
                  radius: 40,
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
        if (showLegend) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: stats.map((stat) {
              String memberName = 'Commun';
              Color memberColor = Colors.grey;
              if (stat.memberId != 'common') {
                final member = members.firstWhere(
                  (m) => m.id == stat.memberId,
                  orElse: () => const Member(
                    id: 'unknown',
                    name: 'Inconnu',
                    icon: Icons.help,
                  ),
                );
                memberName = member.name;
                memberColor = Colors
                    .primaries[member.name.hashCode % Colors.primaries.length];
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: memberColor),
                  const SizedBox(width: 4),
                  Text(
                    '$memberName (${formatCurrency(stat.amount)})',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class HistoryBarChart extends StatelessWidget {
  final List<MonthlyStats> history;
  final bool showTitles;

  const HistoryBarChart({
    super.key,
    required this.history,
    this.showTitles = true,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              history.fold(
                0.0,
                (max, e) => (e.income > e.expense ? e.income : e.expense) > max
                    ? (e.income > e.expense ? e.income : e.expense)
                    : max,
              ) *
              1.2,
          barTouchData: const BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: showTitles,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showTitles,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < history.length) {
                    final date = history[value.toInt()].month;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${date.month}/${date.year.toString().substring(2)}',
                        style: const TextStyle(fontSize: 8),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: history.asMap().entries.map((entry) {
            final index = entry.key;
            final stats = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: stats.income,
                  color: Colors.green,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: stats.expense,
                  color: Colors.red,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
