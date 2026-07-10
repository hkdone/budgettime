import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/inbox_item.dart';
import '../domain/inbox_match_preview.dart';
import 'inbox_controller.dart';
import 'package:budgettime/core/utils/formatters.dart';
import 'package:budgettime/core/utils/responsive_breakpoints.dart';
import '../../../services/open_banking_service.dart';

/// Sync Enable Banking → réel ; notifications captées (Home Assistant) → prévisionnel.
String _defaultInboxTransactionStatus(InboxItem item) {
  final isBankSync = item.metadata?['local_account_id'] != null;
  return isBankSync ? 'effective' : 'projected';
}

class ExternalInboxPage extends ConsumerStatefulWidget {
  const ExternalInboxPage({super.key});

  @override
  ConsumerState<ExternalInboxPage> createState() => _ExternalInboxPageState();
}

class _ExternalInboxPageState extends ConsumerState<ExternalInboxPage> {
  bool _showDebug = false;
  String? _selectedItemId;
  final Set<String> _processingItemIds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxControllerProvider);
    final controller = ref.read(inboxControllerProvider.notifier);
    final useSplitView = context.isWideLayout && state.items.isNotEmpty;

    if (_selectedItemId != null &&
        !state.items.any((i) => i.id == _selectedItemId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedItemId = null);
      });
    }

    InboxItem? selectedItem;
    if (_selectedItemId != null) {
      for (final item in state.items) {
        if (item.id == _selectedItemId) {
          selectedItem = item;
          break;
        }
      }
    } else if (useSplitView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.items.isNotEmpty) {
          setState(() => _selectedItemId = state.items.first.id);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réceptions Externes'),
        actions: [
          IconButton(
            icon: Icon(
              _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
            ),
            tooltip: 'Mode Debug',
            onPressed: () => setState(() => _showDebug = !_showDebug),
          ),
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Synchroniser la banque',
            onPressed: () => _showSyncDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_all') {
                _confirmDeleteAll();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Vider/Reset Inbox'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? _buildEmptyState()
              : useSplitView
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 360,
                          child: _buildInboxList(
                            state.items,
                            compact: true,
                            selectedId: _selectedItemId,
                            onSelect: (item) =>
                                setState(() => _selectedItemId = item.id),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          child: selectedItem != null
                              ? _buildItemDetail(selectedItem)
                              : Center(
                                  child: Text(
                                    'Sélectionnez une réception',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                        ),
                      ],
                    )
                  : _buildInboxList(state.items),
    );
  }

  String _matchSubtitle(InboxMatchPreview match) {
    final delta = match.amountDelta.abs() < 0.01
        ? 'montant identique'
        : match.amountDelta > 0
        ? 'écart ${formatCurrency(-match.amountDelta.abs())}'
        : 'écart +${formatCurrency(match.amountDelta.abs())}';
    final extra = match.matchCount > 1 ? ' (+${match.matchCount - 1})' : '';
    return 'Match : ${match.projectedLabel} (${formatCurrency(match.projectedAmount)}) — $delta$extra';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune nouvelle réception',
            style: TextStyle(color: Colors.grey[600], fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les données envoyées par Home Assistant\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxList(
    List<InboxItem> items, {
    bool compact = false,
    String? selectedId,
    void Function(InboxItem item)? onSelect,
  }) {
    final matchPreviews = ref.watch(inboxControllerProvider).matchPreviews;

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final match = matchPreviews[item.id];
        final isSelected = selectedId == item.id;
        final isProcessing = _processingItemIds.contains(item.id);

        if (compact) {
          return Opacity(
            opacity: isProcessing ? 0.5 : 1,
            child: Material(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : match != null
                      ? Colors.orange.withValues(alpha: 0.06)
                      : null,
              child: ListTile(
                selected: isSelected,
                enabled: !isProcessing,
                leading: CircleAvatar(
                  backgroundColor: match != null
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.blue.withValues(alpha: 0.1),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          match != null
                              ? Icons.link
                              : Icons.account_balance_wallet,
                          color: match != null ? Colors.orange : Colors.blue,
                        ),
                ),
                title: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(item.date),
                ),
                trailing: item.amount != 0
                    ? Text(
                        formatCurrency(item.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.amount >= 0 ? Colors.green : Colors.red,
                        ),
                      )
                    : null,
                onTap: isProcessing ? null : () => onSelect?.call(item),
              ),
            ),
          );
        }

        return Opacity(
          opacity: isProcessing ? 0.5 : 1,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            clipBehavior: Clip.antiAlias,
            color: match != null ? Colors.orange.withValues(alpha: 0.06) : null,
            child: Column(
              children: [
                ListTile(
                  enabled: !isProcessing,
                  leading: CircleAvatar(
                    backgroundColor: match != null
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.blue.withValues(alpha: 0.1),
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            match != null
                                ? Icons.link
                                : Icons.account_balance_wallet,
                            color: match != null ? Colors.orange : Colors.blue,
                          ),
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(item.date),
                      ),
                      if (match != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _matchSubtitle(match),
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: item.amount != 0
                      ? Text(
                          formatCurrency(item.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: item.amount >= 0 ? Colors.green : Colors.red,
                          ),
                        )
                      : null,
                  onTap: isProcessing ? null : () => _processItem(item),
                ),
                if (_showDebug) _buildDebugPanel(item),
                Padding(
                  padding: const EdgeInsets.only(
                    right: 12.0,
                    bottom: 12.0,
                    left: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed:
                            isProcessing ? null : () => _confirmDelete(item),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Ignorer'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed:
                            isProcessing ? null : () => _processItem(item),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: Text(isProcessing ? 'En cours…' : 'Valider'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemDetail(InboxItem item) {
    final match = ref.watch(inboxControllerProvider).matchPreviews[item.id];
    final isProcessing = _processingItemIds.contains(item.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(DateFormat('dd/MM/yyyy HH:mm').format(item.date)),
          if (item.amount != 0) ...[
            const SizedBox(height: 16),
            Text(
              formatCurrency(item.amount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: item.amount >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
          if (match != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _matchSubtitle(match),
                style: TextStyle(color: Colors.orange[800]),
              ),
            ),
          ],
          if (_showDebug) ...[
            const SizedBox(height: 16),
            _buildDebugPanel(item),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: isProcessing ? null : () => _confirmDelete(item),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Ignorer'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: isProcessing ? null : () => _processItem(item),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(isProcessing ? 'En cours…' : 'Valider'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel(InboxItem item) {
    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RAW DATA (Debug)',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            item.rawPayload ?? 'No raw payload available',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (item.metadata != null) ...[
            const SizedBox(height: 8),
            const Text(
              'METADATA',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            SelectableText(
              item.metadata.toString(),
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout vider ?'),
        content: const Text(
          'Toutes les réceptions externes non traitées seront marquées comme ignorées. Cette opération est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(inboxControllerProvider.notifier).deleteAll();
              Navigator.pop(context);
            },
            child: const Text(
              'Tout supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _processItem(InboxItem item) {
    if (_processingItemIds.contains(item.id)) return;

    setState(() => _processingItemIds.add(item.id));

    // 1. Get preview data from the controller
    final previewData = ref
        .read(inboxControllerProvider.notifier)
        .getPreview(item);

    // 2. Add some metadata for AddTransactionPage
    final Map<String, dynamic> transactionData = {
      if (previewData != null) ...previewData,
      // fallback to basic item data if preview failed
      if (previewData == null) ...{
        'amount': item.amount,
        'label': item.label,
        'date': item.date.toIso8601String(),
        'type': item.amount >= 0 ? 'income' : 'expense',
      },
      // Ensure we don't have an ID that would trigger an "Edit"
      // Sync bancaire → réel ; notifications HA → prévisionnel (sauf si le parser a déjà fixé le statut)
      if (previewData == null || !previewData.containsKey('status'))
        'status': _defaultInboxTransactionStatus(item),
      'id': null,
      'fromInbox': true,
      'inboxItemId': item.id,
      // Auto-Mapping du compte
      if (item.metadata != null && item.metadata!['local_account_id'] != null)
        'account': item.metadata!['local_account_id'],
    };

    // 3. Navigate
    context.push('/add-transaction', extra: transactionData).then((success) {
      if (!mounted) return;
      setState(() => _processingItemIds.remove(item.id));
      if (success == true) {
        ref.read(inboxControllerProvider.notifier).deleteItem(item.id);
        // Sécurise l'UI (certains retours peuvent être lents à propager)
        ref.read(inboxControllerProvider.notifier).refresh();
        setState(() => _selectedItemId = null);
      }
    });
  }

  void _confirmDelete(InboxItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ignorer cette réception ?'),
        content: const Text('Cette opération est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(inboxControllerProvider.notifier).deleteItem(item.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSyncDialog() async {
    final mainContext = context;
    final OpenBankingService bankingService = OpenBankingService();
    List<dynamic> accounts = [];
    bool isLoadingAccounts = true;

    String? selectedAccountId;
    DateTimeRange? selectedDateRange;

    // 1. Fetch accounts
    showDialog(
      context: mainContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentRange = selectedDateRange;
          if (isLoadingAccounts) {
            bankingService
                .getConnectedAccounts()
                .then((value) {
                  setDialogState(() {
                    accounts = value;
                    isLoadingAccounts = false;
                  });
                })
                .catchError((e) {
                  if (!context.mounted) return;
                  setDialogState(() {
                    isLoadingAccounts = false;
                  });
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                });
          }

          return AlertDialog(
            title: const Text('Synchronisation Bancaire'),
            content: isLoadingAccounts
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (accounts.isEmpty)
                        const Text('Aucun compte bancaire lié trouvé.')
                      else
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Compte',
                          ),
                          items: accounts.map((acc) {
                            final localName =
                                acc['expand']?['local_account_id']?['name'];
                            final bankName =
                                acc['expand']?['connection_id']?['bank_name'] ??
                                'Banque';
                            final iban =
                                acc['iban'] ?? acc['remote_account_id'];

                            String label = iban;
                            if (localName != null) {
                              label = '$localName ($iban)';
                            } else if (bankName != 'Banque') {
                              label = '$bankName - $iban';
                            }

                            return DropdownMenuItem<String>(
                              value: acc['remote_account_id'],
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedAccountId = value),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (range != null) {
                            setDialogState(() => selectedDateRange = range);
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          currentRange == null
                              ? 'Choisir les dates'
                              : 'Du ${DateFormat('dd/MM').format(currentRange.start)} au ${DateFormat('dd/MM').format(currentRange.end)}',
                        ),
                      ),
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              if (!isLoadingAccounts && accounts.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    if (selectedAccountId == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez choisir un compte'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context); // Close dialog

                    // Show global loading
                    showDialog(
                      context: mainContext,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final result = await bankingService
                          .syncTransactions(
                            selectedAccountId!,
                            dateStart: currentRange != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(currentRange.start)
                                : null,
                            dateEnd: currentRange != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(currentRange.end)
                                : null,
                          )
                          .timeout(const Duration(seconds: 5));

                      if (mainContext.mounted) {
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sync terminée: ${result['inserted'] ?? 0} transactions ajoutées.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } on TimeoutException {
                      if (mainContext.mounted) {
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Requête envoyée. L\'actualisation se fera en arrière-plan.',
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mainContext.mounted) {
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Synchro échouée ou trop longue (mais peut-être en cours). Erreur: $e',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mainContext.mounted) {
                        Navigator.of(
                          mainContext,
                          rootNavigator: true,
                        ).maybePop();
                        // Rafraîchissement forcé du provider
                        ref.read(inboxControllerProvider.notifier).refresh();
                      }
                    }
                  },
                  child: const Text('Synchroniser'),
                ),
            ],
          );
        },
      ),
    );
  }
}
