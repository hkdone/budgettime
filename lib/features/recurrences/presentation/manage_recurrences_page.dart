import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../accounts/domain/account.dart';
import '../domain/recurrence.dart';
import 'recurrence_controller.dart';

class ManageRecurrencesPage extends ConsumerStatefulWidget {
  const ManageRecurrencesPage({super.key});

  @override
  ConsumerState<ManageRecurrencesPage> createState() =>
      _ManageRecurrencesPageState();
}

class _ManageRecurrencesPageState extends ConsumerState<ManageRecurrencesPage> {
  void _showRecurrenceDialog(
    BuildContext context,
    List<Account> accounts, {
    Recurrence? recurrence,
  }) {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord créer un compte.')),
      );
      return;
    }

    final isEditing = recurrence != null;
    final labelController = TextEditingController(text: recurrence?.label);
    final amountController = TextEditingController(
      text: recurrence?.amount.toString(),
    );
    String selectedAccountId = recurrence?.accountId ?? accounts.first.id;
    String selectedType = recurrence?.type ?? 'expense';
    String selectedFrequency = recurrence?.frequency ?? 'monthly';
    DateTime selectedDate = recurrence?.nextDueDate ?? DateTime.now();
    String? selectedTargetAccountId = recurrence?.targetAccountId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEditing ? 'Modifier la récurrence' : 'Nouvelle récurrence',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Montant (€)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Compte'),
                  items: accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedAccountId = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Revenu')),
                    DropdownMenuItem(value: 'expense', child: Text('Dépense')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Virement'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Fréquence'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Quotidien')),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Hebdomadaire'),
                    ),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Bi-Hebdomadaire (2 sem)'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                    DropdownMenuItem(
                      value: 'bimonthly',
                      child: Text('Bi-Mensuel (2 mois)'),
                    ),
                    DropdownMenuItem(value: 'yearly', child: Text('Annuel')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedFrequency = v!),
                ),
                if (selectedType == 'transfer') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // If editing, use existing target, else null/first available diff from source
                    initialValue: recurrence?.targetAccountId,
                    // Note: recurrence?.targetAccountId might be null if new or not a transfer before.
                    // We need a local state variable for this dropdown?
                    // Ideally yes. BUT `showDialog` is stateless unless we use StatefulBuilder which we do.
                    // But we didn't init `selectedTargetAccountId`.
                    // We need to init it outside.
                    // I will fix this locally by using a variable defined in the builder scope or outside.
                    // The instruction below replaces the whole block, I should fix the initialization first.
                    // See next tool call for initialization fix.
                    decoration: const InputDecoration(
                      labelText: 'Compte Cible',
                    ),
                    items: accounts
                        .where((a) => a.id != selectedAccountId)
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedTargetAccountId = v),
                    validator: (v) => selectedType == 'transfer' && v == null
                        ? 'Veuillez choisir un compte cible'
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Prochaine échéance: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ), // Allow past dates for editing
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final label = labelController.text;
                final amount =
                    double.tryParse(
                      amountController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (label.isNotEmpty && amount > 0) {
                  if (isEditing) {
                    // Update logic (Not implemented in controller yet, will add later)
                    // For now, we might need to delete and recreate or add update method
                    // Actually, let's just delete and recreate for simplicity in this pass if update is complex?
                    // No, better to implement update. But for now, let's assume updateRecurrence is available or we add it.
                    // The user wants to Modify.
                    await ref
                        .read(recurrenceControllerProvider.notifier)
                        .updateRecurrence(
                          recurrence.id,
                          accountId: selectedAccountId,
                          amount: amount,
                          label: label,
                          type: selectedType,
                          frequency: selectedFrequency,
                          nextDueDate: selectedDate,
                          dayOfMonth:
                              (selectedFrequency == 'monthly' ||
                                  selectedFrequency == 'bimonthly')
                              ? selectedDate.day
                              : null,
                          targetAccountId: selectedType == 'transfer'
                              ? selectedTargetAccountId
                              : null,
                        );
                  } else {
                    await ref
                        .read(recurrenceControllerProvider.notifier)
                        .addRecurrence(
                          selectedAccountId,
                          amount,
                          label,
                          selectedType,
                          selectedFrequency,
                          selectedDate,
                          dayOfMonth:
                              (selectedFrequency == 'monthly' ||
                                  selectedFrequency == 'bimonthly')
                              ? selectedDate.day
                              : null,
                          targetAccountId: selectedType == 'transfer'
                              ? selectedTargetAccountId
                              : null,
                        );
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recurrencesAsync = ref.watch(recurrenceControllerProvider);
    final accountsAsync = ref.watch(accountControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Récurrences')),
      body: recurrencesAsync.when(
        data: (recurrences) {
          if (recurrences.isEmpty) {
            return const Center(child: Text('Aucune récurrence configurée.'));
          }
          return ListView.builder(
            itemCount: recurrences.length,
            itemBuilder: (context, index) {
              final r = recurrences[index];
              return ListTile(
                leading: Icon(
                  r.type == 'income'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: r.type == 'income' ? Colors.green : Colors.red,
                ),
                title: Text(r.label),
                subtitle: Text(
                  '${r.frequency} - Prochaine: ${DateFormat('dd/MM/yyyy').format(r.nextDueDate)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${r.amount.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        accountsAsync.whenData((accounts) {
                          _showRecurrenceDialog(
                            context,
                            accounts,
                            recurrence: r,
                          );
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
          onPressed: () => _showRecurrenceDialog(context, accounts),
          child: const Icon(Icons.add),
        ),
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
