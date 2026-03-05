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
  bool _showManualList = false; // Par défaut, cache la liste manuelle

  @override
  void initState() {
    super.initState();
    _fetchAspsps();
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final result = await _bankingService.discoverConnections();
      final added = result['added'] ?? 0;
      final total = result['found'] ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Découverte terminée : $total liaisons trouvées, $added nouvelles ajoutées.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors de la découverte : $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToBank(String bankId) async {
    // Affiche un loader pendant qu'on demande l'URL à notre serveur Go
    showDialog(
      context: context,
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

      if (!mounted) return;
      Navigator.of(context).pop(); // Ferme le loader

      final Uri authUri = Uri.parse(authUrlStr);
      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Impossible d'ouvrir le navigateur.");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Ferme le loader en cas d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liaison Bancaire (Production)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _discoverConnections,
                      child: const Text('Réessayer la découverte'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showManualList = true),
                      child: const Text('Afficher la liste manuelle'),
                    ),
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
                        "Ma banque n'apparaît pas ? Sélection manuelle",
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
