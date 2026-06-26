import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_controller.dart';
import '../../../members/presentation/member_controller.dart';
import 'package:budgettime/core/utils/formatters.dart';
import '../../application/month_stats_service.dart';
import '../dashboard_controller.dart';
import 'statistics_widgets.dart';

/// Stats compactes pour la vue « un compte sélectionné » sur le dashboard.
class AccountStatsCompact extends ConsumerStatefulWidget {
  final Account account;
  final String viewMode;

  const AccountStatsCompact({
    super.key,
    required this.account,
    this.viewMode = 'projected',
  });

  @override
  ConsumerState<AccountStatsCompact> createState() =>
      _AccountStatsCompactState();
}

class _AccountStatsCompactState extends ConsumerState<AccountStatsCompact> {
  int _chartTab = 0;

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final membersAsync = ref.watch(memberControllerProvider);
    final customCategories = ref
        .watch(categoryControllerProvider)
        .maybeWhen(
          data: (cats) => cats.where((c) => !c.isSystem).toList(),
          orElse: () => <Category>[],
        );

    final stats = MonthStatsService.computeForAccount(
      transactions: dashboardState.transactions,
      accountId: widget.account.id,
    );
    final realOnly = widget.viewMode == 'real';
    final periodLabel = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques — $periodLabel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpi(
                  'Revenus',
                  realOnly ? stats.realIncome : stats.projectedIncome,
                  Colors.green,
                ),
                _kpi(
                  'Dépenses',
                  realOnly ? stats.realExpense : stats.projectedExpense,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Catégories')),
                ButtonSegment(value: 1, label: Text('Membres')),
              ],
              selected: {_chartTab},
              onSelectionChanged: (v) => setState(() => _chartTab = v.first),
            ),
            const SizedBox(height: 12),
            if (_chartTab == 0)
              CategoryPieChart(
                stats: stats.expenseStats(realOnly: realOnly),
                totalAmount: realOnly ? stats.realExpense : stats.projectedExpense,
                customCategories: customCategories,
                title: 'Dépenses par catégorie',
              )
            else
              membersAsync.maybeWhen(
                data: (members) => MemberPieChart(
                  stats: stats.expenseStatsByMember(realOnly: realOnly),
                  members: members,
                  totalAmount:
                      realOnly ? stats.realExpense : stats.projectedExpense,
                  title: 'Dépenses par membre',
                ),
                orElse: () => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
