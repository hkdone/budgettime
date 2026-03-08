import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/open_banking_service.dart';

class OpenBankingAccountsPage extends StatefulWidget {
  const OpenBankingAccountsPage({super.key});

  @override
  State<OpenBankingAccountsPage> createState() =>
      _OpenBankingAccountsPageState();
}

class _OpenBankingAccountsPageState extends State<OpenBankingAccountsPage> {
  final OpenBankingService _bankingService = OpenBankingService();
  List<dynamic> _aspsps = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showManualList = false;
  String? _appId;
  bool _hasKey = false;
  List<String> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndBanks();
  }

  Future<void> _loadSettingsAndBanks() async {
    await _fetchSettings();
    if (_appId != null && _hasKey) {
      _fetchAspsps();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _bankingService.getSettings();
      setState(() {
        _appId = settings['app_id'];
        _hasKey = settings['has_key'] ?? false;
        _sessions = List<String>.from(settings['sessions'] ?? []);
      });
    } catch (e) {
      debugPrint(
        'Note: Réglages bancaires non trouvés en base (Optionnel): $e',
      );
      // On continue, le serveur utilisera peut-être les env vars ou le dossier secrets
    }
  }

  Future<void> _fetchAspsps() async {
    try {
      final banks = await _bankingService.getAspsps(country: 'FR');
      setState(() {
        _aspsps = banks;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _discoverConnections() async {
    final localContext = context;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final result = await _bankingService.discoverConnections();
      final added = result['added'] ?? 0;
      final total = result['found'] ?? 0;

      if (localContext.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(
            content: Text(
              'Découverte terminée : $total liaisons trouvées, $added nouvelles ajoutées.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (localContext.mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la découverte : $e';
        });
      }
    } finally {
      if (localContext.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectToBank(String bankId) async {
    final localContext = context;
    // Affiche un loader pendant qu'on demande l'URL à notre serveur Go
    showDialog(
      context: localContext,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String finalBaseUrl = _bankingService.pb.baseURL;
      if (finalBaseUrl == '/' || finalBaseUrl.isEmpty) {
        finalBaseUrl = Uri.base.origin;
      } else if (!finalBaseUrl.startsWith('http')) {
        finalBaseUrl = Uri.parse(
          Uri.base.origin,
        ).resolve(finalBaseUrl).toString();
      }

      if (finalBaseUrl.endsWith('/')) {
        finalBaseUrl = finalBaseUrl.substring(0, finalBaseUrl.length - 1);
      }

      final String redirectUrl = '$finalBaseUrl/api/banking/callback';

      final authUrlStr = await _bankingService.getAuthUrl(bankId, redirectUrl);

      if (localContext.mounted) {
        Navigator.pop(localContext); // Ferme le loader
      }

      final Uri authUri = Uri.parse(authUrlStr);
      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Impossible d\'ouvrir le navigateur.');
      }
    } catch (e) {
      if (localContext.mounted) {
        Navigator.pop(localContext); // Ferme le loader
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSettingsDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Enable Banking'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Approche Sécurisée (Fichier .pem)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le serveur utilise désormais exclusivement le dossier "secrets". Déposez-y votre fichier .pem.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_appId != null && _appId!.isNotEmpty) ...[
                const Text(
                  'Application ID détecté :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _appId!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ] else ...[
                const Text(
                  'Aucun fichier .pem détecté dans le dossier "secrets".',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _hasKey ? Icons.check_circle : Icons.error_outline,
                    color: _hasKey ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasKey
                          ? 'Clé privée (.pem) active.'
                          : 'Veuillez déposer votre fichier .pem dans le dossier /pb/secrets.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasKey ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_sessions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  'Sessions Actives (Requisitions) :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._sessions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: SelectableText(
                        s,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () async {
              final localContext = context;
              await _loadSettingsAndBanks();
              if (localContext.mounted) {
                Navigator.pop(localContext);
                ScaffoldMessenger.of(localContext).showSnackBar(
                  const SnackBar(content: Text('Réglages actualisés')),
                );
              }
            },
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liaison Bancaire (Production)'),
        actions: [
          IconButton(
            icon: Icon(
              _appId != null && _hasKey
                  ? Icons.settings
                  : Icons.settings_suggest,
              color: _appId != null && _hasKey ? null : Colors.orange,
            ),
            onPressed: _showSettingsDialog,
            tooltip: 'Configuration',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && (_appId == null || !_hasKey)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_outlined,
                      size: 60,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Liaison Bancaire Optionnelle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vous n\'avez pas encore configuré d\'identifiant Enable Banking sur ce serveur. Vous pouvez le faire dans les réglages si vous souhaitez synchroniser vos comptes automatiquement.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showSettingsDialog,
                      icon: const Icon(Icons.settings),
                      label: const Text('Configurer maintenant'),
                    ),
                  ],
                ),
              ),
            )
          : _errorMessage.isNotEmpty
          ? Center(child: Text('Erreur: $_errorMessage'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(
                    Icons.account_balance,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Connectez votre banque en un clic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'BudgetTime va récupérer les comptes que vous avez déjà liés sur votre interface Enable Banking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _discoverConnections,
                      icon: const Icon(Icons.sync_alt),
                      label: const Text(
                        'Vérifier mes banques liées',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!_showManualList)
                    TextButton(
                      onPressed: () => setState(() => _showManualList = true),
                      child: const Text(
                        'Ma banque n\'apparaît pas ? Sélection manuelle',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  if (_showManualList) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Sélection manuelle :',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _aspsps.length,
                      itemBuilder: (context, index) {
                        final bank = _aspsps[index];
                        final displayName =
                            bank['full_name'] ??
                            bank['name'] ??
                            'Banque Inconnue';
                        final technicalId = bank['name'] ?? 'unknown';

                        return ListTile(
                          leading: bank['logo'] != null
                              ? Image.network(
                                  bank['logo'],
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.account_balance),
                                )
                              : const Icon(Icons.account_balance),
                          title: Text(displayName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _connectToBank(technicalId),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
