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
  List<dynamic> _institutions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchInstitutions();
  }

  Future<void> _fetchInstitutions() async {
    try {
      final banks = await _bankingService.getInstitutions(country: 'FR');
      setState(() {
        _institutions = banks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
      String finalBaseUrl = _bankingService.pb.baseURL;
      if (finalBaseUrl == '/') {
        finalBaseUrl = Uri.base.origin;
      }
      final String redirectUrl = '$finalBaseUrl/api/banking/callback';

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
          : ListView.builder(
              itemCount: _institutions.length,
              itemBuilder: (context, index) {
                final bank = _institutions[index];
                return ListTile(
                  // Enable Banking renvoie 'name' et l'URL du logo transparent
                  leading: bank['logo'] != null
                      ? Image.network(
                          bank['logo'],
                          width: 50,
                          height: 50,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.account_balance),
                        )
                      : const Icon(Icons.account_balance),
                  title: Text(bank['name']),
                  subtitle: Text(bank['id']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _connectToBank(
                    bank['name'],
                  ), // L'API requiert le nom ou l'id
                );
              },
            ),
    );
  }
}
