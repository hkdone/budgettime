import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/account.dart';
import 'account_controller.dart';

class ManageAccountsPage extends ConsumerStatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  ConsumerState<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends ConsumerState<ManageAccountsPage> {
  void _showAccountDialog(BuildContext context, {Account? accountToEdit}) {
    final isEditing = accountToEdit != null;
    final nameController = TextEditingController(text: accountToEdit?.name);
    final balanceController = TextEditingController(
      text: accountToEdit?.initialBalance.toString(),
    );
    final externalIdController = TextEditingController(
      text: accountToEdit?.externalId,
    );
    String selectedType = accountToEdit?.type ?? 'checking';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Modifier le compte' : 'Ajouter un compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du compte'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(selectedType),
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'checking',
                    child: Text('Compte Courant'),
                  ),
                  DropdownMenuItem(value: 'savings', child: Text('Épargne')),
                  DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(
                  labelText: 'Solde initial (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: externalIdController,
                decoration: const InputDecoration(
                  labelText: 'ID Externe (ex: XXX90101)',
                  helperText: 'Utilisé pour le matching auto des SMS',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text;
                final balance =
                    double.tryParse(
                      balanceController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (name.isNotEmpty) {
                  try {
                    if (isEditing) {
                      await ref
                          .read(accountControllerProvider.notifier)
                          .updateAccount(
                            accountToEdit.id,
                            name,
                            selectedType,
                            balance,
                            externalIdController.text.trim(),
                          );
                    } else {
                      await ref
                          .read(accountControllerProvider.notifier)
                          .addAccount(
                            name,
                            selectedType,
                            balance,
                            externalIdController.text.trim(),
                          );
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                }
              },
              child: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Comptes')),
      body: accountsState.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun compte configuré.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAccountDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un compte'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                onTap: () =>
                    _showAccountDialog(context, accountToEdit: account),
                leading: Icon(
                  account.type == 'savings'
                      ? Icons.savings
                      : account.type == 'cash'
                      ? Icons.money
                      : Icons.account_balance,
                  color: Colors.blueAccent,
                ),
                title: Text(account.name),
                subtitle: Text(
                  'Solde initial: ${account.initialBalance.toStringAsFixed(2)} €',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.event, color: Colors.purple),
                      tooltip: 'Voir les échéances',
                      onPressed: () {
                        context.push('/account-recurrences', extra: account.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showAccountDialog(context, accountToEdit: account),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        // Confirm delete
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer ?'),
                            content: const Text(
                              'Voulez-vous vraiment supprimer ce compte et toutes ses transactions ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(accountControllerProvider.notifier)
                                      .deleteAccount(account.id);
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
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
      floatingActionButton:
          accountsState.hasValue && accountsState.value!.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAccountDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
