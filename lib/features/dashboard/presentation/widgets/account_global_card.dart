import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/account_controller.dart';
import '../dashboard_controller.dart';
import 'package:budgettime/core/utils/formatters.dart';

class AccountGlobalCard extends ConsumerWidget {
  final Account account;

  const AccountGlobalCard({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(account));
    final dashboardState = ref.watch(dashboardControllerProvider);

    // Calculate month-to-date totals for THIS account from the global state
    double accountIncome = 0;
    double accountExpense = 0;

    for (final t in dashboardState.transactions) {
      final amount = (t['amount'] as num).toDouble();
      final isTransfer =
          t['target_account'] != null &&
          t['target_account'].toString().isNotEmpty;

      bool isIncomeFlow = t['type'] == 'income';

      if (isTransfer) {
        if (t['target_account'] == account.id) {
          isIncomeFlow = true;
        } else if (t['account'] == account.id) {
          isIncomeFlow = false;
        } else {
          continue; // Not related to this account
        }
      } else if (t['account'] != account.id) {
        continue; // Not related to this account
      }

      if (isIncomeFlow) {
        accountIncome += amount;
      } else {
        accountExpense += amount;
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

              // Simple Month Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    'Revenus',
                    accountIncome,
                    Colors.green,
                    Icons.trending_up,
                  ),
                  _buildStatItem(
                    context,
                    'Dépenses',
                    accountExpense,
                    Colors.red,
                    Icons.trending_down,
                  ),
                  _buildStatItem(
                    context,
                    'Reste',
                    accountIncome - accountExpense,
                    (accountIncome - accountExpense) >= 0
                        ? Colors.blue
                        : Colors.orange,
                    Icons.account_balance_wallet,
                  ),
                ],
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
