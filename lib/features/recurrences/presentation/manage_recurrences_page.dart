import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../accounts/domain/account.dart';
import 'recurrence_controller.dart';

class ManageRecurrencesPage extends ConsumerStatefulWidget {
  const ManageRecurrencesPage({super.key});

  @override
  ConsumerState<ManageRecurrencesPage> createState() =>
      _ManageRecurrencesPageState();
}

class _ManageRecurrencesPageState extends ConsumerState<ManageRecurrencesPage> {
  void _showAddRecurrenceDialog(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord créer un compte.')),
      );
      return;
    }

    final labelController = TextEditingController();
    final amountController = TextEditingController();
    String selectedAccountId = accounts.first.id;
    String selectedType = 'expense';
    String selectedFrequency = 'monthly';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle récurrence'),
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
                    DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                    DropdownMenuItem(value: 'yearly', child: Text('Annuel')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedFrequency = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Prochaine échéance: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
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
                  await ref
                      .read(recurrenceControllerProvider.notifier)
                      .addRecurrence(
                        selectedAccountId,
                        amount,
                        label,
                        selectedType,
                        selectedFrequency,
                        selectedDate,
                        dayOfMonth: selectedFrequency == 'monthly'
                            ? selectedDate.day
                            : null,
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Ajouter'),
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
                  '${r.frequency} - Prochaine: ${DateFormat('dd/MM').format(r.nextDueDate)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${r.amount.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        ref
                            .read(recurrenceControllerProvider.notifier)
                            .deleteRecurrence(r.id);
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
          onPressed: () => _showAddRecurrenceDialog(context, accounts),
          child: const Icon(Icons.add),
        ),
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
