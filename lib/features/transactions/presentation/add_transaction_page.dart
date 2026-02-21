import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/start_app.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../recurrences/presentation/recurrence_controller.dart';
import '../../categories/presentation/category_controller.dart';
import '../../recurrences/domain/recurrence.dart';
import '../../accounts/presentation/account_controller.dart';
import '../../recurrences/application/recurrence_service.dart';
import '../../members/presentation/member_controller.dart';

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

  String _type = 'expense'; // 'income' or 'expense'
  String? _selectedAccountId;
  String? _targetAccountId; // For transfers
  String? _selectedMemberId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurrenceFrequency = 'monthly';
  String _status = 'projected';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unused_result
      ref.refresh(accountControllerProvider);
      // ignore: unused_result
      ref.refresh(categoryControllerProvider);
      // ignore: unused_result
      ref.refresh(memberControllerProvider);
    });

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;

      // If it's an edit (has id)
      if (t['id'] != null) {
        _amountController.text = (t['amount'] as num?)?.toString() ?? '';
        _labelController.text = t['label'] ?? '';
        _categoryController.text = t['category'] ?? '';
        _type = t['type'] ?? 'expense';
        _status = t['status'] ?? 'projected';
        _date = t['date'] != null ? DateTime.parse(t['date']) : DateTime.now();

        if (t['expand'] != null && t['expand']['account'] != null) {
          _selectedAccountId = t['expand']['account']['id'];
        } else {
          _selectedAccountId = t['account'];
        }

        if (t['expand'] != null && t['expand']['member'] != null) {
          _selectedMemberId = t['expand']['member']['id'];
        } else {
          _selectedMemberId = t['member'];
        }

        if (t['expand'] != null && t['expand']['recurrence'] != null) {
          final recurrence = t['expand']['recurrence'];
          _isRecurring = true;
          _recurrenceFrequency = recurrence['frequency'] ?? 'monthly';
          if (!['weekly', 'monthly', 'yearly'].contains(_recurrenceFrequency)) {
            _recurrenceFrequency = 'monthly';
          }
        }
      }

      // If it's a pre-filled account (for both edit and new)
      if (t['accountId'] != null) {
        _selectedAccountId = t['accountId'];
      }
    }
  }

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

  Future<void> _submit({required bool stayOnPage}) async {
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
          'date': _date.toUtc().toString().split('.')[0],
          'category': category,
          'account': _selectedAccountId,
          'member': _selectedMemberId,
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
              await ref
                  .read(transactionRepositoryProvider)
                  .updateTransaction(widget.transactionToEdit!['id'], data);
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
          Recurrence? createdRecurrence;
          if (_isRecurring && _selectedAccountId != null) {
            DateTime nextDueDate = _date;
            if (_recurrenceFrequency == 'weekly') {
              nextDueDate = _date.add(const Duration(days: 7));
            } else if (_recurrenceFrequency == 'biweekly') {
              nextDueDate = _date.add(const Duration(days: 14));
            } else if (_recurrenceFrequency == 'monthly') {
              nextDueDate = DateTime(_date.year, _date.month + 1, _date.day);
            } else if (_recurrenceFrequency == 'bimonthly') {
              nextDueDate = DateTime(_date.year, _date.month + 2, _date.day);
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
                  dayOfMonth:
                      (_recurrenceFrequency == 'monthly' ||
                          _recurrenceFrequency == 'bimonthly')
                      ? _date.day
                      : null,
                  targetAccountId: _type == 'transfer'
                      ? _targetAccountId
                      : null,
                );
          }

          if (createdRecurrence != null) {
            data['recurrence'] = createdRecurrence.id;
          }

          if (_type == 'transfer' && _targetAccountId != null) {
            await ref
                .read(transactionRepositoryProvider)
                .addTransfer(
                  sourceAccountId: _selectedAccountId!,
                  targetAccountId: _targetAccountId!,
                  amount: amount,
                  date: _date,
                  label: label,
                  category: category,
                  recurrenceId: createdRecurrence?.id,
                  status: _status,
                );
          } else {
            await ref.read(transactionRepositoryProvider).addTransaction(data);
          }

          if (createdRecurrence != null) {
            final oneYearLater = DateTime.now().add(const Duration(days: 365));
            await ref
                .read(recurrenceServiceProvider)
                .generateProjectedTransactions(
                  recurrence: createdRecurrence,
                  periodEnd: oneYearLater,
                );
          }
        }

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

          if (stayOnPage) {
            context.pushReplacement(
              '/add-transaction',
              extra: {'accountId': _selectedAccountId},
            );
          } else {
            context.pop();
          }
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
    final isEditing =
        widget.transactionToEdit != null &&
        widget.transactionToEdit!['id'] != null;
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
                  ButtonSegment(
                    value: 'transfer',
                    label: Text('Virement'),
                    icon: Icon(Icons.swap_horiz),
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
              Consumer(
                builder: (context, ref, child) {
                  final categoriesAsync = ref.watch(categoryControllerProvider);
                  return Row(
                    children: [
                      Expanded(
                        child: categoriesAsync.when(
                          data: (categories) {
                            return DropdownButtonFormField<String>(
                              key: ValueKey(_categoryController.text),
                              isExpanded: true,
                              initialValue:
                                  categories.any(
                                    (c) => c.id == _categoryController.text,
                                  )
                                  ? _categoryController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                              ),
                              items: categories.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      Icon(c.icon, color: c.color, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: c.isSystem
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _categoryController.text = value;
                                  });
                                }
                              },
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Veuillez choisir une catégorie'
                                  : null,
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, s) => Text('Erreur: $e'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showAddCategoryDialog(context, ref),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Créer une catégorie',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
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
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Bi-hebdomadaire'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                    DropdownMenuItem(
                      value: 'bimonthly',
                      child: Text('Bi-mensuel'),
                    ),
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
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, child) {
                  final membersAsync = ref.watch(memberControllerProvider);
                  return membersAsync.when(
                    data: (members) {
                      if (members.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String>(
                        key: ValueKey(_selectedMemberId),
                        initialValue: _selectedMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Membre',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.family_restroom, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Commun'),
                              ],
                            ),
                          ),
                          ...members.map((member) {
                            return DropdownMenuItem(
                              value: member.id,
                              child: Row(
                                children: [
                                  Icon(member.icon, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Text(member.name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMemberId = value;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Erreur: $e'),
                  );
                },
              ),
              const SizedBox(height: 16),
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
                      if (_selectedAccountId == null && accounts.isNotEmpty) {
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
              if (_type == 'transfer') ...[
                Consumer(
                  builder: (context, ref, child) {
                    final accountsAsync = ref.watch(accountControllerProvider);
                    return accountsAsync.when(
                      data: (accounts) {
                        final targetAccounts = accounts
                            .where((a) => a.id != _selectedAccountId)
                            .toList();
                        if (targetAccounts.isEmpty) {
                          return const Text(
                            'Veuillez créer au moins deux comptes pour effectuer un virement.',
                            style: TextStyle(color: Colors.red),
                          );
                        }
                        if (_targetAccountId == _selectedAccountId) {
                          Future.microtask(() {
                            if (mounted) {
                              setState(() => _targetAccountId = null);
                            }
                          });
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey('target_$_targetAccountId'),
                          initialValue: _targetAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Compte Cible',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.login),
                          ),
                          items: targetAccounts.map((account) {
                            return DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _targetAccountId = value;
                            });
                          },
                          validator: (value) {
                            if (_type == 'transfer' && value == null) {
                              return 'Veuillez sélectionner un compte cible';
                            }
                            return null;
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text('Erreur: $e'),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submit(stayOnPage: false),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _submit(stayOnPage: true),
                      child: const Text('Enregistrer et Nouveau'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    // ignore: deprecated_member_use
    int selectedColor = Colors.blue.value;
    int selectedIcon = Icons.category.codePoint;
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];
    final icons = [
      Icons.local_grocery_store,
      Icons.restaurant,
      Icons.commute,
      Icons.home,
      Icons.health_and_safety,
      Icons.school,
      Icons.sports_esports,
      Icons.pets,
      Icons.shopping_bag,
      Icons.work,
      Icons.savings,
      Icons.flight,
      Icons.movie,
      Icons.miscellaneous_services,
      Icons.build,
      Icons.local_gas_station,
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nouvelle Catégorie'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Couleur',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors
                        .map(
                          (c) => InkWell(
                            onTap: () {
                              // ignore: deprecated_member_use
                              setState(() => selectedColor = c.value);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                // ignore: deprecated_member_use
                                border: selectedColor == c.value
                                    ? Border.all(color: Colors.black, width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Icône',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons
                        .map(
                          (icon) => InkWell(
                            onTap: () =>
                                setState(() => selectedIcon = icon.codePoint),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedIcon == icon.codePoint
                                    ? Colors.grey[200]
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: Color(selectedColor)),
                            ),
                          ),
                        )
                        .toList(),
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
                  if (nameController.text.isNotEmpty) {
                    await ref
                        .read(categoryControllerProvider.notifier)
                        .addCategory(
                          name: nameController.text,
                          iconCodePoint: selectedIcon,
                          colorHex: selectedColor,
                        );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
