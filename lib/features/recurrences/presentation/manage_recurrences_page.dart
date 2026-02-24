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
        data: (recurrences) {
          if (recurrences.isEmpty) {
            return const Center(child: Text('Aucune récurrence configurée.'));
          }
          final accounts = accountsAsync.value ?? [];

          return ListView.builder(
            itemCount: recurrences.length,
            itemBuilder: (context, index) {
              final r = recurrences[index];
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
                title: Text(r.label),
                subtitle: Text(
                  '${account?.name ?? "Inconnu"} - ${r.frequency} - Prochaine: ${DateFormat('dd/MM/yyyy').format(r.nextDueDate)}',
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
