import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../accounts/domain/account.dart';
import '../../../statistics/presentation/statistics_controller.dart';
import '../../../statistics/presentation/widgets/statistics_charts.dart';
import '../../../members/presentation/member_controller.dart';
import '../../../accounts/presentation/account_controller.dart';

class AccountGlobalCard extends ConsumerWidget {
  final Account account;

  const AccountGlobalCard({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(accountStatsProvider(account.id));
    final membersAsync = ref.watch(memberControllerProvider);
    final balanceAsync = ref.watch(accountBalanceProvider(account));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    '${balance.toStringAsFixed(2)} €',
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
            statsAsync.when(
              data: (stats) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 400;

                    return Column(
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CategoryPieChart(
                                  stats: stats.expenseByCategory,
                                  totalAmount: stats.totalExpense,
                                  showLegend: true,
                                ),
                              ),
                              Expanded(
                                child: membersAsync.maybeWhen(
                                  data: (members) => MemberPieChart(
                                    stats: stats.expenseByMember,
                                    members: members,
                                    totalAmount: stats.totalExpense,
                                    title: 'Membres',
                                    showLegend: true,
                                  ),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: CategoryPieChart(
                                  stats: stats.expenseByCategory,
                                  totalAmount: stats.totalExpense,
                                  showLegend: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: HistoryBarChart(
                                  history: stats.history,
                                  showTitles: false,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isWide)
                          HistoryBarChart(history: stats.history)
                        else
                          membersAsync.maybeWhen(
                            data: (members) => MemberPieChart(
                              stats: stats.expenseByMember,
                              members: members,
                              totalAmount: stats.totalExpense,
                              title: 'Dépenses membres',
                              showLegend: true,
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, s) => Center(child: Text('Erreur: $e')),
            ),
          ],
        ),
      ),
    );
  }
}
