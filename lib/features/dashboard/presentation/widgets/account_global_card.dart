import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../accounts/domain/account.dart';
import '../../../members/presentation/member_controller.dart';
import '../../../accounts/presentation/account_controller.dart';
import '../dashboard_controller.dart';
import 'statistics_widgets.dart';
import 'package:budgettime/core/utils/formatters.dart';

class _LocalStats {
  double totalIncome = 0;
  double totalExpense = 0;
  double totalVirementIn = 0;
  double totalVirementOut = 0;
  Map<String, double> incomeByCategory = {};
  Map<String, double> expenseByCategory = {};
  Map<String, double> incomeByMember = {};
  Map<String, double> expenseByMember = {};

  List<CategoryStats> get expenseStats {
    if (totalExpense == 0) return [];
    final list = expenseByCategory.entries
        .map(
          (e) => CategoryStats(
            categoryId: e.key,
            amount: e.value,
            percentage: (e.value / totalExpense) * 100,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<MemberStats> get expenseStatsByMember {
    if (totalExpense == 0) return [];
    final list = expenseByMember.entries
        .map(
          (e) => MemberStats(
            memberId: e.key,
            amount: e.value,
            percentage: (e.value / totalExpense) * 100,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<MemberStats> get incomeStatsByMember {
    if (totalIncome == 0) return [];
    final list = incomeByMember.entries
        .map(
          (e) => MemberStats(
            memberId: e.key,
            amount: e.value,
            percentage: (e.value / totalIncome) * 100,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }
}

class AccountGlobalCard extends ConsumerWidget {
  final Account account;

  const AccountGlobalCard({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final membersAsync = ref.watch(memberControllerProvider);
    final balanceAsync = ref.watch(accountBalanceProvider(account));

    // Calculate month-to-date totals for THIS account from the global state
    final stats = _LocalStats();

    for (final t in dashboardState.transactions) {
      final amount = (t['amount'] as num).toDouble();
      final isTransfer =
          t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty;

      String role = 'none';
      if (isTransfer) {
        if (t['target_account'] == account.id) {
          role = 'income';
        } else if (t['account'] == account.id) {
          role = 'expense';
        }
      } else if (t['account'] == account.id) {
        role = t['type'] == 'income' ? 'income' : 'expense';
      }

      if (role == 'none') continue;

      final categoryId = t['category'] ?? 'unknown';
      final memberId = t['member'] ?? 'common';

      if (role == 'income') {
        if (isTransfer) {
          stats.totalVirementIn += amount;
        } else {
          stats.totalIncome += amount;
          stats.incomeByCategory[categoryId] =
              (stats.incomeByCategory[categoryId] ?? 0) + amount;
          stats.incomeByMember[memberId] =
              (stats.incomeByMember[memberId] ?? 0) + amount;
        }
      } else {
        if (isTransfer) {
          stats.totalVirementOut += amount;
        } else {
          stats.totalExpense += amount;
          stats.expenseByCategory[categoryId] =
              (stats.expenseByCategory[categoryId] ?? 0) + amount;
          stats.expenseByMember[memberId] =
              (stats.expenseByMember[memberId] ?? 0) + amount;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(dashboardControllerProvider.notifier).selectAccount(account);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Account Name & Balance
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
                          child: Text(
                            account.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
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
              const Divider(height: 24),

              // Statistics Content
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            'Revenus',
                            stats.totalIncome,
                            Colors.green,
                            Icons.trending_up,
                          ),
                          _buildStatItem(
                            context,
                            'Dépenses',
                            stats.totalExpense,
                            Colors.red,
                            Icons.trending_down,
                          ),
                          _buildStatItem(
                            context,
                            'Reste',
                            (stats.totalIncome + stats.totalVirementIn) -
                                (stats.totalExpense + stats.totalVirementOut),
                            ((stats.totalIncome + stats.totalVirementIn) -
                                        (stats.totalExpense +
                                            stats.totalVirementOut)) >=
                                    0
                                ? Colors.blue
                                : Colors.orange,
                            Icons.account_balance_wallet,
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (stats.totalExpense > 0)
                              Expanded(
                                child: CategoryPieChart(
                                  stats: stats.expenseStats,
                                  totalAmount: stats.totalExpense,
                                  showLegend: true,
                                ),
                              ),
                            if (stats.totalExpense > 0)
                              Expanded(
                                child: membersAsync.maybeWhen(
                                  data: (members) => MemberPieChart(
                                    stats: stats.expenseStatsByMember,
                                    members: members,
                                    totalAmount: stats.totalExpense,
                                    title: 'Dépenses membres',
                                    showLegend: true,
                                  ),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ),
                            if (stats.totalIncome > 0)
                              Expanded(
                                child: membersAsync.maybeWhen(
                                  data: (members) => MemberPieChart(
                                    stats: stats.incomeStatsByMember,
                                    members: members,
                                    totalAmount: stats.totalIncome,
                                    title: 'Recettes membres',
                                    showLegend: true,
                                  ),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            if (stats.totalExpense > 0)
                              CategoryPieChart(
                                stats: stats.expenseStats,
                                totalAmount: stats.totalExpense,
                                showLegend: true,
                              ),
                            if (stats.totalExpense > 0 ||
                                stats.totalIncome > 0) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (stats.totalExpense > 0)
                                    Expanded(
                                      child: membersAsync.maybeWhen(
                                        data: (members) => MemberPieChart(
                                          stats: stats.expenseStatsByMember,
                                          members: members,
                                          totalAmount: stats.totalExpense,
                                          title: 'Dépenses membres',
                                          showLegend: true,
                                        ),
                                        orElse: () => const SizedBox.shrink(),
                                      ),
                                    ),
                                  if (stats.totalIncome > 0) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: membersAsync.maybeWhen(
                                        data: (members) => MemberPieChart(
                                          stats: stats.incomeStatsByMember,
                                          members: members,
                                          totalAmount: stats.totalIncome,
                                          title: 'Recettes membres',
                                          showLegend: true,
                                        ),
                                        orElse: () => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
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
