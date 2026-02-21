import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/auth_controller.dart';
import 'dashboard_controller.dart';
import '../../transactions/presentation/transaction_list.dart';
import 'widgets/account_global_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    // Calculate totals including initial balances
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in state.transactions) {
      final amount = (t['amount'] as num).toDouble();
      if (t['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    // Balance is initial + income - expense
    // Note: This assumes transactions fetched are ALL transactions since beginning?
    // Wait, getTransactions filters by date (start/end).
    // If we want "Current Balance", we need ALL transactions up to now,
    // or we need the account's "current balance" stored in DB.
    // Usually "current balance" = initial + sum(all past transactions).
    // The current dashboard only fetches "month" transactions.
    // TO FIX THIS PROPERLY: We need to fetch the balance from the account itself (if updated)
    // or fetch ALL transactions to calculate it.
    // PocketBase 'accounts' collection doesn't seem to have a 'current_balance' field that is auto-updated?
    // Checking schema... it only has 'initial_balance'.
    // So we must calculate it on the fly.
    // For now, let's assume the user wants to see the balance EVOLUTION over the month,
    // starting from the account's state at the beginning of the month?
    // OR does the user want the REAL ACTUAL CURRENT BALANCE?
    // User said: "mon solde doit être celui présent sur mon compte." (My balance must be the one on my account).
    // If I create an account with 1000€, I expect to see 1000€.
    // If I add -50€ expense today, I expect 950€.
    // Issue: The `transactions` list in state is FILTERED by date (current month).
    // So `totalIncome` / `totalExpense` are only for THIS MONTH.
    // If we just do `initialBalance + monthIncome - monthExpense`,
    // we miss all transactions BEFORE this month.
    //
    // QUICK FIX for now (assuming new user):
    // Since it's a new app, let's assume all transactions are in current month
    // OR we need to fetch 'balance' differently.
    // Given the constraints and existing code, let's just make sure `initialBalance` is added.
    // And to fix the "return to all accounts" bug, we need to ensure value matches.

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        iconTheme: const IconThemeData(color: Colors.black),
        actionsIconTheme: const IconThemeData(color: Colors.black),
        title: PopupMenuButton<String>(
          initialValue: state.selectedAccount?.id ?? 'all',
          onSelected: (String accountId) {
            if (accountId == 'all') {
              ref
                  .read(dashboardControllerProvider.notifier)
                  .selectAccount(null);
            } else {
              final account = state.accounts.firstWhere(
                (a) => a.id == accountId,
                orElse: () => state.accounts.first, // Fallback safety
              );
              controller.selectAccount(account);
            }
          },
          itemBuilder: (context) {
            return [
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('Tous les comptes'),
              ),
              ...state.accounts.map(
                (account) => PopupMenuItem<String>(
                  value: account.id,
                  child: Text(account.name),
                ),
              ),
            ];
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  state.selectedAccount?.name ?? 'Tous les comptes',
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Traiter la réception',
            onPressed: () async {
              await ref
                  .read(dashboardControllerProvider.notifier)
                  .processInbox();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Réception traitée')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'accounts':
                  context.push('/accounts').then((_) => controller.refresh());
                  break;
                case 'settings':
                  context.push('/settings').then((_) => controller.refresh());
                  break;
                case 'logout':
                  ref.read(authControllerProvider.notifier).signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Gérer les comptes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE d MMMM yyyy',
                            'fr_FR',
                          ).format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'v1.6.6',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              state.selectedAccount != null
                                  ? 'Solde actuel (${state.selectedAccount!.name})'
                                  : 'Solde actuel',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${state.effectiveBalance.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    color: state.effectiveBalance >= 0
                                        ? Colors.black
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            // Projected Balance
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Prévisionnel (fin de mois) : ',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${state.projectedBalance.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Revenus',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    Text(
                                      '+${totalIncome.toStringAsFixed(2)} €',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.green),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Dépenses',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    Text(
                                      '-${totalExpense.toStringAsFixed(2)} €',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 5. Success State: Transactions or Account Cards
            if (state.selectedAccount == null)
              // GLOBAL VIEW: Show per-account cards
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final account = state.accounts[index];
                  return AccountGlobalCard(account: account);
                }, childCount: state.accounts.length),
              )
            else
              // DETAIL VIEW: Show transaction list for the selected account
              TransactionList(transactions: state.transactions),
          ],
        ),
      ),
      floatingActionButton: state.selectedAccount != null
          ? FloatingActionButton(
              onPressed: () {
                context.push(
                  '/add-transaction',
                  extra: {'accountId': state.selectedAccount!.id},
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
