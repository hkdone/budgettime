import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/inbox_item.dart';
import 'inbox_controller.dart';
import '../../transactions/presentation/add_transaction_page.dart';
import 'package:budgettime/core/utils/formatters.dart';
import '../../../services/open_banking_service.dart';

class ExternalInboxPage extends ConsumerStatefulWidget {
  const ExternalInboxPage({super.key});

  @override
  ConsumerState<ExternalInboxPage> createState() => _ExternalInboxPageState();
}

class _ExternalInboxPageState extends ConsumerState<ExternalInboxPage> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxControllerProvider);
    final controller = ref.read(inboxControllerProvider.notifier);

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
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
          ? _buildEmptyState()
          : _buildInboxList(state.items),
    );
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

  Widget _buildInboxList(List<InboxItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue,
                  ),
                ),
                title: Text(
                  item.label,
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
                          fontSize: 16,
                          color: item.amount >= 0 ? Colors.green : Colors.red,
                        ),
                      )
                    : null,
                onTap: () => _processItem(item),
              ),
              if (_showDebug) _buildDebugPanel(item),
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmDelete(item),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Ignorer'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _processItem(item),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Valider'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  void _processItem(InboxItem item) {
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
      'id': null,
      'fromInbox': true,
    };

    // 3. Navigate
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionPage(transactionToEdit: transactionData),
      ),
    ).then((success) {
      if (success == true) {
        // If the transaction was added, mark the inbox item as processed
        ref.read(inboxControllerProvider.notifier).deleteItem(item.id);
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
    final OpenBankingService bankingService = OpenBankingService();
    List<dynamic> accounts = [];
    bool isLoadingAccounts = true;

    String? selectedAccountId;
    DateTimeRange? selectedDateRange;

    // 1. Fetch accounts
    showDialog(
      context: context,
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

                    if (!context.mounted) return;
                    // Show global loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final result = await bankingService.syncTransactions(
                        selectedAccountId!,
                        dateStart: currentRange != null
                            ? DateFormat(
                                'yyyy-MM-dd',
                              ).format(currentRange.start)
                            : null,
                        dateEnd: currentRange != null
                            ? DateFormat('yyyy-MM-dd').format(currentRange.end)
                            : null,
                      );

                      if (context.mounted) {
                        Navigator.pop(context); // Remove loader
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sync terminée: ${result['inserted']} transactions ajoutées.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        ref.read(inboxControllerProvider.notifier).refresh();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loader
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
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
