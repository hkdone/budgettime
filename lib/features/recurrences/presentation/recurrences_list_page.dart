import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import '../../recurrences/presentation/recurrence_controller.dart';
import '../../recurrences/domain/recurrence.dart'; // Import Recurrence model
import 'recurrence_dialog.dart';
import '../../accounts/presentation/account_controller.dart';

class RecurrencesListPage extends ConsumerWidget {
  final String accountId;

  const RecurrencesListPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurrencesAsync = ref.watch(recurrenceControllerProvider);
    final accountsAsync = ref.watch(accountControllerProvider);

    final accountName =
        accountsAsync.value
            ?.firstWhere(
              (a) => a.id == accountId,
              orElse: () => throw Exception('Account not found'),
            )
            .name ??
        'Compte';

    return Scaffold(
      appBar: AppBar(title: Text('Échéances : $accountName')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(recurrenceControllerProvider.notifier)
              .getRecurrences();
        },
        child: recurrencesAsync.when(
          data: (allRecurrences) {
            final recurrences = allRecurrences
                .where((r) => r.accountId == accountId && r.active)
                .toList();

            if (recurrences.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 50),
                  Center(
                    child: Text('Aucune récurrence active pour ce compte.'),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recurrences.length,
              itemBuilder: (context, index) {
                final recurrence = recurrences[index];
                final stats = _calculateStats(recurrence);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                recurrence.label,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${recurrence.amount.toStringAsFixed(2)} €',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: recurrence.type == 'income'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () {
                                        accountsAsync.whenData((accounts) {
                                          RecurrenceDialog.show(
                                            context,
                                            ref,
                                            accounts,
                                            recurrence: recurrence,
                                          );
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Supprimer ?'),
                                            content: const Text(
                                              'Voulez-vous vraiment supprimer cette récurrence ?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Supprimer'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          ref
                                              .read(
                                                recurrenceControllerProvider
                                                    .notifier,
                                              )
                                              .deleteRecurrence(recurrence.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _translateFrequency(recurrence.frequency),
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Prochaine : ${DateFormat('dd/MM/yyyy').format(recurrence.nextDueDate)}',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sur 1 an :',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                Text(
                                  '${stats.count} occurrences restantes',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (stats.lastDate != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Dernière projection :',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(stats.lastDate!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Erreur: $err')),
        ),
      ),
    );
  }

  String _translateFrequency(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 'Hebdomadaire';
      case 'monthly':
        return 'Mensuel';
      case 'yearly':
        return 'Annuel';
      case 'daily':
        return 'Quotidien';
      default:
        return frequency;
    }
  }

  ({int count, DateTime? lastDate}) _calculateStats(Recurrence recurrence) {
    DateTime current = recurrence.nextDueDate;
    // Limit to 1 year from now as per system behavior
    final end = DateTime.now().add(const Duration(days: 365));
    int count = 0;
    DateTime? lastDate;

    // Safety constraint
    int iterations = 0;
    while (current.isBefore(end) && iterations < 366) {
      count++;
      lastDate = current;

      if (recurrence.frequency == 'weekly') {
        current = current.add(const Duration(days: 7));
      } else if (recurrence.frequency == 'monthly') {
        current = DateTime(current.year, current.month + 1, current.day);
      } else if (recurrence.frequency == 'yearly') {
        current = DateTime(current.year + 1, current.month, current.day);
      } else if (recurrence.frequency == 'daily') {
        current = current.add(const Duration(days: 1));
      } else {
        break;
      }
      iterations++;
    }

    return (count: count, lastDate: lastDate);
  }
}
