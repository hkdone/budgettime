import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../accounts/domain/account.dart';
import '../domain/recurrence.dart';
import 'recurrence_controller.dart';
import '../../transactions/domain/categories.dart';

class RecurrenceDialog {
  static void show(
    BuildContext context,
    WidgetRef ref,
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
    String selectedCategoryId = recurrence?.categoryId ?? 'other';

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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: kTransactionCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(c.icon, size: 18, color: c.color),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCategoryId = v!),
                ),
                if (selectedType == 'transfer') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTargetAccountId,
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
                          ),
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
                          categoryId: selectedCategoryId,
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
                          categoryId: selectedCategoryId,
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
}
