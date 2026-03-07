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
  String? _sessionId;

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
        _sessionId = settings['session_id'];
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des réglages: $e');
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
    final appIdController = TextEditingController(text: _appId);
    final keyController =
        TextEditingController(); // On ne préremplit pas la clé pour la sécu

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Enable Banking'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chaque instance de BudgetTime doit avoir son propre compte Enable Banking (gratuit).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: appIdController,
                decoration: const InputDecoration(
                  labelText: 'Application ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'RSA Private Key (PEM)',
                  hintText: '-----BEGIN RSA PRIVATE KEY-----...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_sessionId != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'Session ID actuelle: $_sessionId',
                  style: const TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final localContext = context;
              try {
                await _bankingService.saveSettings(
                  appId: appIdController.text,
                  privateKey: keyController.text,
                );
                if (localContext.mounted) {
                  Navigator.pop(localContext);
                  _loadSettingsAndBanks();
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    const SnackBar(content: Text('Réglages sauvegardés')),
                  );
                }
              } catch (e) {
                if (localContext.mounted) {
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Sauvegarder'),
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
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _appId == null || !_hasKey
                          ? Icons.warning_amber
                          : Icons.info_outline,
                      size: 60,
                      color: _appId == null || !_hasKey
                          ? Colors.red
                          : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _appId == null || !_hasKey
                          ? 'Configuration manquante'
                          : 'Importation manuelle requise',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _appId == null || !_hasKey
                          ? 'Veuillez configurer votre Application ID et votre Clé RSA dans les réglages.'
                          : 'Si vous avez déjà lié vos banques sur Enable Banking, l\'API ne permet pas de les lister automatiquement sans Session ID.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_appId == null || !_hasKey)
                      ElevatedButton.icon(
                        onPressed: _showSettingsDialog,
                        icon: const Icon(Icons.settings),
                        label: const Text('Ouvrir les réglages'),
                      )
                    else ...[
                      ElevatedButton(
                        onPressed: _discoverConnections,
                        child: const Text('Tenter une découverte automatique'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showManualList = true),
                        child: const Text('Afficher la liste manuelle'),
                      ),
                    ],
                  ],
                ),
              ),
            )
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
