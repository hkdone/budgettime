import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/start_app.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../recurrences/application/recurrence_service.dart';
import '../../recurrences/presentation/recurrence_controller.dart';
import '../domain/categories.dart';
import '../../recurrences/domain/recurrence.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? transactionToEdit;

  const AddTransactionPage({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh accounts to ensure list is up to date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final _ = ref.refresh(accountControllerProvider);
    });

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _amountController.text = (t['amount'] as num).toString();
      _labelController.text = t['label'] ?? '';
      _categoryController.text = t['category'] ?? '';
      _type = t['type'] ?? 'expense';
      _status = t['status'] ?? 'effective';
      _date = DateTime.parse(t['date']); // Assuming UTC string

      // Handle account selection (might need to wait for accounts to load?)
      // Since we just triggered refresh, account list might not be ready.
      // But _selectedAccountId is used logic.
      if (t['expand'] != null && t['expand']['account'] != null) {
        _selectedAccountId = t['expand']['account']['id'];
      } else {
        // Fallback if not expanded but id is there (depends on how we pass data)
        _selectedAccountId = t['account'];
      }

      // Pre-fill Recurrence details
      if (t['expand'] != null && t['expand']['recurrence'] != null) {
        final recurrence = t['expand']['recurrence'];
        _isRecurring = true;
        _recurrenceFrequency = recurrence['frequency'] ?? 'monthly';
        // Ensure valid value
        if (!['weekly', 'monthly', 'yearly'].contains(_recurrenceFrequency)) {
          _recurrenceFrequency = 'monthly';
        }
      }
    }
  }

  String _type = 'expense'; // 'income' or 'expense'
  String? _selectedAccountId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurrenceFrequency = 'monthly';
  String _status = 'effective';

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final amount = double.parse(
          _amountController.text.replaceAll(',', '.'),
        );
        final label = _labelController.text;
        final category = _categoryController.text;

        final data = {
          'amount': amount,
          'label': label,
          'type': _type,
          'date': _date.toUtc().toIso8601String(),
          'category': category,
          'account': _selectedAccountId,
          'status': _status,
          'is_automatic': false,
        };

        if (widget.transactionToEdit != null) {
          final isRecurrent =
              widget.transactionToEdit!['recurrence'] != null &&
              widget.transactionToEdit!['recurrence'].toString().isNotEmpty;

          if (!isRecurrent) {
            await ref
                .read(transactionRepositoryProvider)
                .updateTransaction(widget.transactionToEdit!['id'], data);
          } else {
            // Smart Update Dialog
            // Need to await dialog result, but we are inside _submit
            // Refactor: We should probably ask BEFORE calling this or just show dialog here
            // Showing dialog here since it's an async operation

            if (!mounted) return;
            final choice = await showDialog<String>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Modification récurrence'),
                children: [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, 'single'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Modifier uniquement celle-ci'),
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, 'future'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Modifier celle-ci et les futures'),
                    ),
                  ),
                ],
              ),
            );

            if (choice == 'single') {
              await ref
                  .read(transactionRepositoryProvider)
                  .updateTransaction(widget.transactionToEdit!['id'], data);
            } else if (choice == 'future') {
              // Update current
              await ref
                  .read(transactionRepositoryProvider)
                  .updateTransaction(widget.transactionToEdit!['id'], data);

              // Update future
              await ref
                  .read(transactionRepositoryProvider)
                  .updateFutureTransactions(
                    widget.transactionToEdit!['recurrence'],
                    DateTime.parse(widget.transactionToEdit!['date']),
                    data,
                  );
            }
          }
        } else {
          // 1. Create Recurrence FIRST
          Recurrence? createdRecurrence;
          if (_isRecurring && _selectedAccountId != null) {
            DateTime nextDueDate = _date;
            if (_recurrenceFrequency == 'weekly') {
              nextDueDate = _date.add(const Duration(days: 7));
            } else if (_recurrenceFrequency == 'monthly') {
              nextDueDate = DateTime(_date.year, _date.month + 1, _date.day);
            } else if (_recurrenceFrequency == 'yearly') {
              nextDueDate = DateTime(_date.year + 1, _date.month, _date.day);
            }

            createdRecurrence = await ref
                .read(recurrenceControllerProvider.notifier)
                .addRecurrence(
                  _selectedAccountId!,
                  amount,
                  label,
                  _type,
                  _recurrenceFrequency,
                  nextDueDate,
                  dayOfMonth: _recurrenceFrequency == 'monthly'
                      ? _date.day
                      : null,
                );
          }

          // 2. Link to transaction
          if (createdRecurrence != null) {
            data['recurrence'] = createdRecurrence.id;
          }

          // 3. Create Transaction
          await ref.read(transactionRepositoryProvider).addTransaction(data);

          // 4. Generate Projections
          if (createdRecurrence != null) {
            // Generate projected transactions for the next year
            final oneYearLater = DateTime.now().add(const Duration(days: 365));
            await ref
                .read(recurrenceServiceProvider)
                .generateProjectedTransactions(
                  recurrence: createdRecurrence,
                  periodEnd: oneYearLater,
                );
          }
        }

        // Refresh dashboard
        await ref.read(dashboardControllerProvider.notifier).refresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.transactionToEdit != null
                    ? 'Transaction modifiée avec succès'
                    : 'Transaction ajoutée avec succès',
              ),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ajout : $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionToEdit != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier la transaction' : 'Ajouter une transaction',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selection
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Dépense'),
                    icon: Icon(Icons.money_off),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('Revenu'),
                    icon: Icon(Icons.attach_money),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _type = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Status Selection
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'effective',
                    label: Text('Réel'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: 'projected',
                    label: Text('Prévisionnel'),
                    icon: Icon(Icons.access_time),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _status = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Label
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Libellé',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un libellé';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                key: ValueKey(_categoryController.text),
                initialValue: _categoryController.text.isEmpty
                    ? null
                    : _categoryController.text,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: [
                  // Add a "None" or "Custom" option if needed, or just map the list
                  ...kTransactionCategories.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(c.icon, color: c.color, size: 20),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _categoryController.text = value;
                    });
                  }
                },
                validator: (value) =>
                    value == null ? 'Veuillez choisir une catégorie' : null,
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(_date)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Recurrence Toggle
              SwitchListTile(
                title: const Text('Répéter'),
                value: _isRecurring,
                onChanged: (bool value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _recurrenceFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Fréquence',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Hebdomadaire'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                    DropdownMenuItem(value: 'yearly', child: Text('Annuel')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _recurrenceFrequency = value;
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 32),

              // Account Selection
              Consumer(
                builder: (context, ref, child) {
                  final accountsAsync = ref.watch(accountControllerProvider);
                  return accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text(
                          'Veuillez d\'abord créer un compte.',
                          style: TextStyle(color: Colors.red),
                        );
                      }
                      // Auto-select first if null
                      if (_selectedAccountId == null && accounts.isNotEmpty) {
                        // Defer update to avoid build error
                        Future.microtask(() {
                          if (mounted) {
                            setState(() {
                              _selectedAccountId = accounts.first.id;
                            });
                          }
                        });
                      }

                      return DropdownButtonFormField<String>(
                        key: ValueKey(_selectedAccountId),
                        initialValue: _selectedAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Compte',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          return DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAccountId = value;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Veuillez sélectionner un compte'
                            : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Erreur: $e'),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Submit Button
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
