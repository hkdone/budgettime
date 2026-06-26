import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../accounts/domain/account.dart';
import '../../../members/presentation/member_controller.dart';
import '../../../accounts/presentation/account_controller.dart';
import '../../../categories/presentation/category_controller.dart';
import '../../../categories/domain/category.dart';
import '../dashboard_controller.dart';
import '../../application/month_stats_service.dart';
import 'statistics_widgets.dart';
import 'package:budgettime/core/utils/formatters.dart';
import 'package:budgettime/core/utils/responsive_breakpoints.dart';

class AccountGlobalCard extends ConsumerStatefulWidget {
  final Account account;

  const AccountGlobalCard({super.key, required this.account});

  @override
  ConsumerState<AccountGlobalCard> createState() => _AccountGlobalCardState();
}

class _AccountGlobalCardState extends ConsumerState<AccountGlobalCard> {
  String _viewMode = 'projected';
  int _chartTab = 0;

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final membersAsync = ref.watch(memberControllerProvider);
    final balanceAsync = ref.watch(accountBalanceProvider(widget.account));
    final List<Category> customCategories = ref
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref
              .read(dashboardControllerProvider.notifier)
              .selectAccount(widget.account);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.account_balance,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.account.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                periodLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  balanceAsync.when(
                    data: (balance) => Text(
                      formatCurrency(balance),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (e, s) => const Icon(Icons.error, color: Colors.red),
                  ),
                ],
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
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Revenus', income, Colors.green, Icons.trending_up),
                  _buildStatItem('Dépenses', expense, Colors.red, Icons.trending_down),
                  _buildStatItem(
                    'Reste',
                    (balanceAsync.value ?? 0) +
                        (realOnly ? 0 : stats.projectedDelta),
                    ((balanceAsync.value ?? 0) + stats.projectedDelta) >= 0
                        ? Colors.blue
                        : Colors.orange,
                    Icons.account_balance_wallet,
                  ),
                ],
              ),
              if (expense > 0 || income > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
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
                            title: 'Dépenses catégories',
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
                                title: 'Dépenses membres',
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
                                title: 'Recettes membres',
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
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.6), size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
