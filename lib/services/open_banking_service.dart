import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../core/services/database_service.dart';

class OpenBankingService {
  final PocketBase pb = DatabaseService().pb;

  /// 1. Récupère la liste des Banques (ASPSPs) via notre serveur PocketBase
  Future<List<dynamic>> getAspsps({String country = 'FR'}) async {
    try {
      final url = Uri.parse(
        pb.baseURL,
      ).resolve('api/banking/aspsps?country=$country');
      // On passe le token de la session utilisateur pour sécuriser l'accès (Même si public pour l'instant)
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['aspsps'] ?? [];
      } else {
        throw Exception(
          'Erreur API ASPSPs: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Impossible de charger les banques : $e');
    }
  }

  /// 2. Récupère l'URL d'autorisation (Redirect Bank URL) pour la banque choisie
  Future<String> getAuthUrl(String bankId, String redirectUrl) async {
    try {
      final url = Uri.parse(pb.baseURL).resolve('api/banking/auth');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': pb.authStore.token,
        },
        body: json.encode({
          'bank_id': bankId,
          'country': 'FR',
          'redirect_url': redirectUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url']; // Enable Banking renvoie 'url'
      } else {
        throw Exception(
          'Erreur API Auth: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Impossible d\'initier la connexion bancaire : $e');
    }
  }

  /// 3. L'utilisateur a fini sur la banque, on valide le 'code' côté serveur
  Future<String> confirmCallback(String code) async {
    try {
      final url = Uri.parse(
        pb.baseURL,
      ).resolve('api/banking/callback?code=$code');
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['session_id']; // Le fameux requisition_id
      } else {
        throw Exception('Erreur API Callback: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de valider le consentement: $e');
    }
  }

  /// 4. Récupère les comptes bancaires (IBANs) liés à l'utilisateur
  Future<List<dynamic>> getConnectedAccounts() async {
    try {
      final records = await pb
          .collection('bank_accounts')
          .getFullList(
            expand:
                'connection_id,local_account_id', // Expansion pour afficher noms banques et comptes locaux
          );
      return records.map((r) => r.toJson()).toList();
    } catch (e) {
      throw Exception('Impossible de charger vos comptes bancaires liés: $e');
    }
  }

  /// 5. Lie un compte bancaire distant à un compte BudgetTime local
  Future<void> linkAccount(String bankAccountId, String localAccountId) async {
    try {
      await pb
          .collection('bank_accounts')
          .update(bankAccountId, body: {'local_account_id': localAccountId});
    } catch (e) {
      throw Exception('Impossible de lier le compte: $e');
    }
  }

  /// 6. Découvre les connexions existantes (Mode Personnel)
  Future<Map<String, dynamic>> discoverConnections() async {
    try {
      final url = Uri.parse(pb.baseURL).resolve('api/banking/discover');
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Erreur Discovery: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau lors du Discovery : $e');
    }
  }

  /// 5. Lance la synchronisation API manuelle avec Enable Banking
  Future<Map<String, dynamic>> syncTransactions(
    String accountId, {
    String? dateStart,
    String? dateEnd,
  }) async {
    try {
      final baseUri = Uri.parse(pb.baseURL);
      var urlStr = baseUri
          .resolve('api/banking/sync?account_id=$accountId')
          .toString();
      if (dateStart != null) urlStr += '&date_start=$dateStart';
      if (dateEnd != null) urlStr += '&date_end=$dateEnd';

      final url = Uri.parse(urlStr);
      final response = await http
          .get(url, headers: {'Authorization': pb.authStore.token})
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Échec de la synchronisation: $e');
    }
  }

  /// 6. Récupère les réglages Enable Banking (App ID, etc.)
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final url = Uri.parse(pb.baseURL).resolve('api/banking/settings');
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'app_id': data['app_id'],
          'has_key': data['has_key'],
          'sessions': data['sessions'] ?? [],
        };
      } else {
        throw Exception('Erreur Settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de charger les réglages : $e');
    }
  }

  /// 6.5 Supprimer une session bancaire
  Future<void> deleteSession(String sessionId) async {
    try {
      final url = Uri.parse(
        pb.baseURL,
      ).resolve('api/banking/sessions/$sessionId');
      final response = await http.delete(
        url,
        headers: {'Authorization': pb.authStore.token},
      );
      if (response.statusCode != 200) {
        throw Exception('Erreur suppression session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Impossible de supprimer la session : $e');
    }
  }

  /// 7. Sauvegarde les réglages Enable Banking
  Future<void> saveSettings({
    required String appId,
    String? privateKey,
    String? sessionId,
  }) async {
    try {
      final url = Uri.parse(pb.baseURL).resolve('api/banking/settings');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': pb.authStore.token,
        },
        body: json.encode({
          'app_id': appId,
          'private_key': privateKey ?? '',
          'session_id': sessionId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur sauvegarde: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de sauvegarder les réglages : $e');
    }
  }
}
