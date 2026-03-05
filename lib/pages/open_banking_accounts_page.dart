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
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _discoverConnections() async {
    setState(() => _isLoading = true);
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
      // On rafraîchit la page ou on ferme ?
      // Si on a ajouté des comptes, l'utilisateur peut maintenant revenir au dashboard
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la découverte : $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      // 1. Définir l'URL de redirection dynamiquement (v0.23+ compatible)
      // On privilégie l'URL du navigateur si on est sur le web, sinon le baseURL de PocketBase
      String finalBaseUrl = _bankingService.pb.baseURL;
      if (finalBaseUrl == '/' || finalBaseUrl.isEmpty) {
        finalBaseUrl = Uri.base.origin;
      } else if (!finalBaseUrl.startsWith('http')) {
        // En cas de baseURL relative
        finalBaseUrl = Uri.parse(
          Uri.base.origin,
        ).resolve(finalBaseUrl).toString();
      }

      // Nettoyage des slashs finaux pour éviter les doubles slashs
      if (finalBaseUrl.endsWith('/')) {
        finalBaseUrl = finalBaseUrl.substring(0, finalBaseUrl.length - 1);
      }

      final String redirectUrl = '$finalBaseUrl/api/banking/callback';
      debugPrint('[OpenBanking] Using Redirect URL: $redirectUrl');

      // 2. Obtenir l'Auth URL depuis Enable Banking (via notre serveur)
      final authUrlStr = await _bankingService.getAuthUrl(bankId, redirectUrl);

      if (!mounted) return;
      Navigator.of(context).pop(); // Ferme le loader

      // 3. Ouvrir le navigateur sécurisé du téléphone
      final Uri authUri = Uri.parse(authUrlStr);
      if (await canLaunchUrl(authUri)) {
        await launchUrl(
          authUri,
          mode: LaunchMode.externalApplication,
        ); // Force le navigateur externe
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
      appBar: AppBar(title: const Text('Sélectionner une Banque')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _discoverConnections,
                    icon: const Icon(Icons.sync_alt),
                    label: const Text(
                      'Vérifier mes banques liées (Mode Personnel)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Ou sélectionnez une banque manuellement :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
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
                                width: 50,
                                height: 50,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.account_balance),
                              )
                            : const Icon(Icons.account_balance),
                        title: Text(displayName),
                        subtitle: Text(technicalId),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _connectToBank(technicalId),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
