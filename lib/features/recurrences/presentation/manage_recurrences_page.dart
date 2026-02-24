import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../members/presentation/member_controller.dart';
import 'recurrence_controller.dart';
import 'recurrence_dialog.dart';
import 'package:budgettime/core/utils/formatters.dart';

class ManageRecurrencesPage extends ConsumerStatefulWidget {
  const ManageRecurrencesPage({super.key});

  @override
  ConsumerState<ManageRecurrencesPage> createState() =>
      _ManageRecurrencesPageState();
}

class _ManageRecurrencesPageState extends ConsumerState<ManageRecurrencesPage> {
  @override
  Widget build(BuildContext context) {
    final recurrencesAsync = ref.watch(recurrenceControllerProvider);
    final accountsAsync = ref.watch(accountControllerProvider);
    final membersAsync = ref.watch(memberControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Récurrences')),
      body: recurrencesAsync.when(
        data: (state) {
          final recurrences = state.recurrences;
          final counts = state.projectionsCount;

          if (recurrences.isEmpty) {
            return const Center(child: Text('Aucune récurrence configurée.'));
          }
          final accounts = accountsAsync.value ?? [];

          return ListView.builder(
            itemCount: recurrences.length,
            itemBuilder: (context, index) {
              final r = recurrences[index];
              final count = counts[r.id] ?? 0;
              final isLow = count <= 5;

              final account = accounts.any((a) => a.id == r.accountId)
                  ? accounts.firstWhere((a) => a.id == r.accountId)
                  : null;

              return ListTile(
                leading: Icon(
                  r.type == 'income'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: r.type == 'income' ? Colors.green : Colors.red,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(r.label)),
                    if (isLow)
                      const Tooltip(
                        message: 'Bientôt à court de projections',
                        child: Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${account?.name ?? "Inconnu"} - ${r.frequency} - Prochaine: ${DateFormat('dd/MM/yyyy').format(r.nextDueDate)}',
                    ),
                    Row(
                      children: [
                        Text(
                          'Projections restantes : $count',
                          style: TextStyle(
                            color: isLow ? Colors.orange : Colors.grey[600],
                            fontWeight: isLow
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        if (isLow)
                          TextButton(
                            onPressed: () => ref
                                .read(recurrenceControllerProvider.notifier)
                                .rechargeRecurrence(r),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Recharger (1 an)',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(r.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        accountsAsync.whenData((accounts) {
                          membersAsync.whenData((members) {
                            RecurrenceDialog.show(
                              context,
                              ref,
                              accounts,
                              members,
                              recurrence: r,
                            );
                          });
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
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
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref
                              .read(recurrenceControllerProvider.notifier)
                              .deleteRecurrence(r.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
      floatingActionButton: accountsAsync.when(
        data: (accounts) => FloatingActionButton(
          onPressed: () {
            membersAsync.whenData((members) {
              RecurrenceDialog.show(context, ref, accounts, members);
            });
          },
          child: const Icon(Icons.add),
        ),
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
