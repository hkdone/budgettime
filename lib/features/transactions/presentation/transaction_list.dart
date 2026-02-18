import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

import '../../../core/start_app.dart';

class TransactionList extends ConsumerWidget {
  final List<dynamic> transactions;

  const TransactionList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'Aucune transaction pour cette période',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isIncome = transaction['type'] == 'income';
        final amount = (transaction['amount'] as num).toDouble();
        final status = transaction['status'] ?? 'effective';
        final isProjected = status == 'projected';

        return Card(
          elevation: isProjected ? 0 : 1,
          color: isProjected ? Colors.grey[50] : null,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              transaction['label'] ?? 'No Label',
              style: TextStyle(
                fontStyle: isProjected ? FontStyle.italic : FontStyle.normal,
                color: isProjected ? Colors.grey[700] : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(transaction['date'])),
                ),
                if (isProjected)
                  const Text(
                    'Prévisionnel',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: isProjected
                        ? Colors.grey
                        : (isIncome ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context
                          .push('/add-transaction', extra: transaction)
                          .then(
                            (_) => ref
                                .read(dashboardControllerProvider.notifier)
                                .refresh(),
                          );
                    } else if (value == 'delete') {
                      final isRecurrent =
                          transaction['recurrence'] != null &&
                          transaction['recurrence'].toString().isNotEmpty;

                      if (!isRecurrent) {
                        // Standard delete
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmer la suppression'),
                            content: const Text(
                              'Voulez-vous vraiment supprimer cette transaction ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await ref
                              .read(transactionRepositoryProvider)
                              .deleteTransaction(transaction['id']);
                          // Refresh dashboard
                          await ref
                              .read(dashboardControllerProvider.notifier)
                              .refresh();
                        }
                      } else {
                        // Smart Delete for Recurrence
                        final choice = await showDialog<String>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('Suppression récurrence'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(context, 'single'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text('Supprimer uniquement celle-ci'),
                                ),
                              ),
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(context, 'future'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'Supprimer celle-ci et les futures',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (choice == 'single') {
                          await ref
                              .read(transactionRepositoryProvider)
                              .deleteTransaction(transaction['id']);
                        } else if (choice == 'future') {
                          await ref
                              .read(transactionRepositoryProvider)
                              .deleteFutureTransactions(
                                transaction['recurrence'],
                                DateTime.parse(transaction['date']),
                              );
                        }

                        if (choice != null) {
                          await ref
                              .read(dashboardControllerProvider.notifier)
                              .refresh();
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
