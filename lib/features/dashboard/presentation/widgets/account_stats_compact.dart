import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_controller.dart';
import '../../../members/presentation/member_controller.dart';
import 'package:budgettime/core/utils/formatters.dart';
import 'package:budgettime/core/utils/responsive_breakpoints.dart';
import '../../application/month_stats_service.dart';
import '../dashboard_controller.dart';
import 'statistics_widgets.dart';

/// Stats compactes pour la vue « un compte sélectionné » sur le dashboard.
class AccountStatsCompact extends ConsumerStatefulWidget {
  final Account account;

  const AccountStatsCompact({super.key, required this.account});

  @override
  ConsumerState<AccountStatsCompact> createState() =>
      _AccountStatsCompactState();
}

class _AccountStatsCompactState extends ConsumerState<AccountStatsCompact> {
  String _viewMode = 'projected';
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
    final realOnly = _viewMode == 'real';
    final periodLabel = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());
    final income = realOnly ? stats.realIncome : stats.projectedIncome;
    final expense = realOnly ? stats.realExpense : stats.projectedExpense;

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
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'real', label: Text('Réel')),
                ButtonSegment(value: 'projected', label: Text('Prévu')),
              ],
              selected: {_viewMode},
              onSelectionChanged: (v) => setState(() => _viewMode = v.first),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpi('Revenus', income, Colors.green),
                _kpi('Dépenses', expense, Colors.red),
              ],
            ),
            if (expense > 0 || income > 0) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= Breakpoints.compact;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (expense > 0)
                          Expanded(
                            child: CategoryPieChart(
                              stats: stats.expenseStats(realOnly: realOnly),
                              totalAmount: expense,
                              customCategories: customCategories,
                              title: 'Dépenses catégories',
                            ),
                          ),
                        if (expense > 0)
                          Expanded(
                            child: membersAsync.maybeWhen(
                              data: (members) => MemberPieChart(
                                stats: stats.expenseStatsByMember(
                                  realOnly: realOnly,
                                ),
                                members: members,
                                totalAmount: expense,
                                title: 'Dépenses membres',
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ),
                        if (income > 0)
                          Expanded(
                            child: membersAsync.maybeWhen(
                              data: (members) => MemberPieChart(
                                stats: stats.incomeStatsByMember(
                                  realOnly: realOnly,
                                ),
                                members: members,
                                totalAmount: income,
                                title: 'Recettes membres',
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Catégories')),
                          ButtonSegment(value: 1, label: Text('Membres')),
                        ],
                        selected: {_chartTab},
                        onSelectionChanged: (v) =>
                            setState(() => _chartTab = v.first),
                      ),
                      const SizedBox(height: 12),
                      if (_chartTab == 0 && expense > 0)
                        CategoryPieChart(
                          stats: stats.expenseStats(realOnly: realOnly),
                          totalAmount: expense,
                          customCategories: customCategories,
                          title: 'Dépenses par catégorie',
                        ),
                      if (_chartTab == 1) ...[
                        if (expense > 0)
                          membersAsync.maybeWhen(
                            data: (members) => MemberPieChart(
                              stats: stats.expenseStatsByMember(
                                realOnly: realOnly,
                              ),
                              members: members,
                              totalAmount: expense,
                              title: 'Dépenses par membre',
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        if (income > 0) ...[
                          const SizedBox(height: 12),
                          membersAsync.maybeWhen(
                            data: (members) => MemberPieChart(
                              stats: stats.incomeStatsByMember(
                                realOnly: realOnly,
                              ),
                              members: members,
                              totalAmount: income,
                              title: 'Recettes par membre',
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ],
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
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
