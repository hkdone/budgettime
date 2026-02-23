import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budgettime/core/utils/formatters.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../recurrences/presentation/recurrence_controller.dart';

import '../../../core/start_app.dart';

class TransactionList extends ConsumerStatefulWidget {
  final List<dynamic> transactions;

  const TransactionList({super.key, required this.transactions});

  @override
  ConsumerState<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<TransactionList> {
  // Track expansion state: date string -> isExpanded
  final Map<String, bool> _expandedStates = {};

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Aucune transaction pour cette période',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // 1. Group transactions by date
    final groupedTransactions = <String, List<dynamic>>{};
    for (final t in widget.transactions) {
      final label = t['label']?.toString() ?? '';

      // We only hide purely technical transactions.
      // Automatic transfers from recurrences MUST be visible to be validated.
      final isTechnical =
          label == 'Solde Initial' ||
          label == 'Mise à jour solde' ||
          label.contains('Ajustement solde');

      if (isTechnical) continue;

      final dateStr = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.parse(t['date']).toLocal());
      groupedTransactions.putIfAbsent(dateStr, () => []).add(t);
    }

    // 2. Sort dates in ascending order (croissant)
    final sortedDates = groupedTransactions.keys.toList()..sort();

    // 3. Initialize/Update expansion states for Today, Yesterday, Tomorrow
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 1)));
    final tomorrow = DateFormat(
      'yyyy-MM-dd',
    ).format(now.add(const Duration(days: 1)));

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final dateStr = sortedDates[index];
        final dayTransactions = groupedTransactions[dateStr]!;
        final date = DateTime.parse(dateStr);

        // Determine if it should be expanded by default
        final bool isDefaultExpanded =
            dateStr == today || dateStr == yesterday || dateStr == tomorrow;
        final bool isExpanded = _expandedStates[dateStr] ?? isDefaultExpanded;

        return Column(
          children: [
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey(dateStr),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedStates[dateStr] = expanded;
                  });
                },
                title: Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${dayTransactions.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                children: dayTransactions.map((transaction) {
                  final isIncome = transaction['type'] == 'income';
                  final amount = (transaction['amount'] as num).toDouble();
                  final status = transaction['status'] ?? 'effective';
                  final isProjected = status == 'projected';

                  final isTransfer =
                      transaction['target_account'] != null &&
                      transaction['target_account'].toString().isNotEmpty;

                  return Card(
                    elevation: isProjected ? 0 : 2,
                    shadowColor: isProjected ? null : Colors.black12,
                    color: isProjected
                        ? Colors.grey[50]
                        : const Color(
                            0xFFE1F5FE,
                          ), // Light sky blue for effective
                    margin: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: isProjected ? 4 : 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isProjected
                            ? Colors.grey.shade200
                            : Colors.blue.shade300,
                        width: isProjected ? 0.5 : 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isTransfer
                            ? Colors.blue.withValues(alpha: 0.2)
                            : (isIncome
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2)),
                        child: Icon(
                          isTransfer
                              ? Icons.swap_horiz
                              : (isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward),
                          color: isTransfer
                              ? Colors.blue
                              : (isIncome ? Colors.green : Colors.red),
                        ),
                      ),
                      title: Text(
                        transaction['label'] ?? 'No Label',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontStyle: isProjected
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: isProjected ? Colors.grey[700] : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isProjected)
                            Text(
                              DateTime.parse(
                                    transaction['date'],
                                  ).toLocal().isBefore(
                                    DateTime.now().subtract(
                                      const Duration(days: 1),
                                    ),
                                  )
                                  ? 'En retard (À consolider)'
                                  : 'Prévisionnel',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    DateTime.parse(
                                      transaction['date'],
                                    ).toLocal().isBefore(
                                      DateTime.now().subtract(
                                        const Duration(days: 1),
                                      ),
                                    )
                                    ? Colors.red
                                    : Colors.blueGrey,
                                fontWeight:
                                    DateTime.parse(
                                      transaction['date'],
                                    ).toLocal().isBefore(
                                      DateTime.now().subtract(
                                        const Duration(days: 1),
                                      ),
                                    )
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (transaction['expand'] != null &&
                              transaction['expand']['member'] != null) ...[
                            Tooltip(
                              message: transaction['expand']['member']['name'],
                              child: Icon(
                                IconData(
                                  int.parse(
                                    transaction['expand']['member']['icon'],
                                  ),
                                  fontFamily: 'MaterialIcons',
                                ),
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            const Tooltip(
                              message: 'Commun',
                              child: Icon(
                                Icons.family_restroom,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (isProjected)
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                              ),
                              tooltip: 'Valider la transaction',
                              onPressed: () async {
                                await ref
                                    .read(transactionRepositoryProvider)
                                    .updateTransaction(transaction['id'], {
                                      'status': 'effective',
                                    });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Transaction validée'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                                await ref
                                    .read(dashboardControllerProvider.notifier)
                                    .refresh();
                              },
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${isIncome ? '+' : '-'}${formatCurrency(amount)}',
                            style: TextStyle(
                              color: isProjected
                                  ? Colors.grey
                                  : (isTransfer
                                        ? Colors.blue
                                        : (isIncome
                                              ? Colors.green
                                              : Colors.red)),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                context
                                    .push(
                                      '/add-transaction',
                                      extra: transaction,
                                    )
                                    .then(
                                      (_) => ref
                                          .read(
                                            dashboardControllerProvider
                                                .notifier,
                                          )
                                          .refresh(),
                                    );
                              } else if (value == 'delete') {
                                final isRecurrent =
                                    transaction['recurrence'] != null &&
                                    transaction['recurrence']
                                        .toString()
                                        .isNotEmpty;

                                if (!isRecurrent) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Confirmer la suppression',
                                      ),
                                      content: const Text(
                                        'Voulez-vous vraiment supprimer cette transaction ?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
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
                                    await ref
                                        .read(
                                          dashboardControllerProvider.notifier,
                                        )
                                        .refresh();
                                  }
                                } else {
                                  final choice = await showDialog<String>(
                                    context: context,
                                    builder: (context) => SimpleDialog(
                                      title: const Text(
                                        'Suppression récurrence',
                                      ),
                                      children: [
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.pop(context, 'single'),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              'Supprimer uniquement celle-ci',
                                            ),
                                          ),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.pop(context, 'future'),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
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
                                    String recurrenceId = '';
                                    final rawRecurrence =
                                        transaction['recurrence'];
                                    if (rawRecurrence is String) {
                                      recurrenceId = rawRecurrence;
                                    } else if (rawRecurrence is Map) {
                                      recurrenceId =
                                          rawRecurrence['id']?.toString() ?? '';
                                    }

                                    if (recurrenceId.isNotEmpty) {
                                      await ref
                                          .read(transactionRepositoryProvider)
                                          .deleteTransaction(transaction['id']);
                                      await ref
                                          .read(transactionRepositoryProvider)
                                          .deleteFutureTransactions(
                                            recurrenceId,
                                            DateTime.parse(transaction['date']),
                                          );
                                    }
                                  }

                                  if (choice != null) {
                                    await ref
                                        .read(
                                          dashboardControllerProvider.notifier,
                                        )
                                        .refresh();
                                    ref.invalidate(
                                      recurrenceControllerProvider,
                                    );
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
                                    Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
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
                }).toList(),
              ),
            ),
          ],
        );
      }, childCount: sortedDates.length),
    );
  }
}
