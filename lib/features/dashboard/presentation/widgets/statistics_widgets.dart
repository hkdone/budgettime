import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../transactions/domain/categories.dart';
import '../../../members/domain/member.dart';
import 'package:budgettime/core/utils/formatters.dart';
import 'package:budgettime/core/utils/app_theme.dart';
import '../../application/month_stats_service.dart';

class CategoryStats {
  final String categoryId;
  final double amount;
  final double percentage;

  CategoryStats({
    required this.categoryId,
    required this.amount,
    required this.percentage,
  });
}

class MemberStats {
  final String memberId;
  final double amount;
  final double percentage;

  MemberStats({
    required this.memberId,
    required this.amount,
    required this.percentage,
  });
}

class MonthlyStats {
  final DateTime month;
  final double income;
  final double expense;

  MonthlyStats({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}

class ChartSliceItem {
  final String id;
  final String label;
  final double amount;
  final double percentage;
  final Color color;

  const ChartSliceItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

List<ChartSliceItem> groupChartSlices({
  required List<ChartSliceItem> items,
  double minPercent = 5,
}) {
  if (items.isEmpty) return [];
  final main = <ChartSliceItem>[];
  double othersAmount = 0;
  double othersPercent = 0;

  for (final item in items) {
    if (item.percentage >= minPercent) {
      main.add(item);
    } else {
      othersAmount += item.amount;
      othersPercent += item.percentage;
    }
  }

  if (othersAmount > 0) {
    main.add(
      ChartSliceItem(
        id: '__others__',
        label: 'Autres',
        amount: othersAmount,
        percentage: othersPercent,
        color: Colors.grey,
      ),
    );
  }

  return main;
}

class StatsEmptyChart extends StatelessWidget {
  final String? title;

  const StatsEmptyChart({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
            ],
            Icon(Icons.pie_chart_outline, color: Colors.grey[400], size: 28),
            const SizedBox(height: 4),
            Text(
              'Aucune donnée',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsDonutChart extends StatelessWidget {
  final List<ChartSliceItem> slices;
  final String centerLabel;
  final String? title;
  final bool showLegend;

  const StatsDonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.title,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return StatsEmptyChart(title: title);

    return Column(
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: slices.map((slice) {
                    return PieChartSectionData(
                      color: slice.color,
                      value: slice.amount,
                      title: slice.percentage >= 8
                          ? '${slice.percentage.round()}%'
                          : '',
                      radius: 48,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    formatCurrency(
                      slices.fold(0.0, (sum, s) => sum + s.amount),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 88),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: slices.map((slice) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${slice.label} · ${formatCurrency(slice.amount)} (${slice.percentage.round()}%)',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CategoryPieChart extends StatelessWidget {
  final List<CategoryStats> stats;
  final double totalAmount;
  final bool showLegend;
  final List<Category> customCategories;
  final String? title;

  const CategoryPieChart({
    super.key,
    required this.stats,
    required this.totalAmount,
    this.showLegend = true,
    this.customCategories = const [],
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty || totalAmount <= 0) {
      return StatsEmptyChart(title: title);
    }

    final allCategories = [...kTransactionCategories, ...customCategories];
    final rawSlices = stats.map((catStat) {
      final category = allCategories.firstWhere(
        (c) => c.id == catStat.categoryId,
        orElse: () => const Category(
          id: 'other',
          name: 'Autre',
          icon: Icons.label_outline,
          color: Colors.grey,
        ),
      );
      return ChartSliceItem(
        id: catStat.categoryId,
        label: category.name,
        amount: catStat.amount,
        percentage: catStat.percentage,
        color: category.color,
      );
    }).toList();

    return StatsDonutChart(
      title: title,
      centerLabel: 'Total',
      showLegend: showLegend,
      slices: groupChartSlices(items: rawSlices),
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

  Color _memberColor(String memberId, String memberName) {
    if (memberId == 'common') return Colors.grey;
    return AppColors.memberPalette[memberName.hashCode.abs() %
        AppColors.memberPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty || totalAmount <= 0) return const SizedBox.shrink();

    final rawSlices = stats.map((stat) {
      String memberName = 'Commun';
      if (stat.memberId != 'common') {
        memberName = members
            .firstWhere(
              (m) => m.id == stat.memberId,
              orElse: () => const Member(
                id: 'unknown',
                name: 'Commun',
                icon: Icons.help,
              ),
            )
            .name;
      }
      return ChartSliceItem(
        id: stat.memberId,
        label: memberName,
        amount: stat.amount,
        percentage: stat.percentage,
        color: _memberColor(stat.memberId, memberName),
      );
    }).toList();

    return StatsDonutChart(
      title: title,
      centerLabel: 'Total',
      showLegend: showLegend,
      slices: groupChartSlices(items: rawSlices),
    );
  }
}

class GenericBreakdownPieChart extends StatelessWidget {
  final Map<String, double> data;
  final Map<String, String> nameLookup;
  final Color baseColor;
  final String? title;

  const GenericBreakdownPieChart({
    super.key,
    required this.data,
    required this.nameLookup,
    required this.baseColor,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return StatsEmptyChart(title: title);

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = [
      baseColor,
      baseColor.withValues(alpha: 0.8),
      baseColor.withValues(alpha: 0.6),
      ...AppColors.chartPalette,
    ];

    final rawSlices = sorted.asMap().entries.map((entry) {
      final index = entry.key;
      final val = entry.value;
      final percentage = (val.value / total) * 100;
      final displayName = nameLookup[val.key] ??
          MonthStatsService.categoryDisplayName(val.key, nameLookup);
      return ChartSliceItem(
        id: val.key,
        label: displayName,
        amount: val.value,
        percentage: percentage,
        color: palette[index % palette.length],
      );
    }).toList();

    return StatsDonutChart(
      title: title,
      centerLabel: 'Total',
      slices: groupChartSlices(items: rawSlices),
    );
  }
}

class HistoryBarChart extends StatelessWidget {
  final List<MonthlyStats> history;
  final bool showTitles;
  final String? title;

  const HistoryBarChart({
    super.key,
    required this.history,
    this.showTitles = true,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final maxVal = history.fold<double>(0, (max, e) {
      final peak = e.income > e.expense ? e.income : e.expense;
      return peak > max ? peak : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.25,
              barTouchData: const BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: showTitles,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showTitles,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < history.length) {
                        final date = history[index].month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${date.month}/${date.year.toString().substring(2)}',
                            style: const TextStyle(fontSize: 9),
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
              gridData: const FlGridData(show: false),
              barGroups: history.asMap().entries.map((entry) {
                final index = entry.key;
                final stats = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: stats.income,
                      color: AppColors.chartIncome,
                      width: 10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    BarChartRodData(
                      toY: stats.expense,
                      color: AppColors.chartExpense,
                      width: 10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _legendDot(AppColors.chartIncome, 'Revenus'),
            const SizedBox(width: 12),
            _legendDot(AppColors.chartExpense, 'Dépenses'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class SignedYearlyBarChart extends StatelessWidget {
  final List<MonthlyStats> trends;
  final String? title;

  const SignedYearlyBarChart({
    super.key,
    required this.trends,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const StatsEmptyChart();

    final maxAbs = trends.fold<double>(0, (max, t) {
      final abs = t.balance.abs();
      return abs > max ? abs : max;
    });
    final chartMax = maxAbs == 0 ? 100.0 : maxAbs * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartHeight = constraints.maxHeight - 24;
              final zeroY = chartHeight / 2;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trends.map((trend) {
                  final heightFactor = (trend.balance.abs() / chartMax).clamp(
                    0.04,
                    1.0,
                  );
                  final barHeight = (chartHeight / 2) * heightFactor;
                  final isPositive = trend.balance >= 0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCurrency(trend.balance),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: chartHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: zeroY,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              if (isPositive)
                                Positioned(
                                  bottom: chartHeight - zeroY,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.chartIncome.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  top: zeroY,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.chartExpense.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          trend.month.year.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MonthlyBalanceBarChart extends StatelessWidget {
  final List<MonthlyStats> months;
  final String? title;

  const MonthlyBalanceBarChart({
    super.key,
    required this.months,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final items = months
        .map(
          (m) => MonthlyStats(
            month: m.month,
            income: m.income,
            expense: m.expense,
          ),
        )
        .toList();
    return HistoryBarChart(
      history: items,
      title: title ?? 'Revenus vs Dépenses par mois',
    );
  }
}
