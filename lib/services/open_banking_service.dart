import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../core/services/database_service.dart';

class OpenBankingService {
  final PocketBase pb = DatabaseService().pb;

  /// 1. Récupère la liste des Banques (Institutions) via notre serveur PocketBase
  Future<List<dynamic>> getInstitutions({String country = 'FR'}) async {
    try {
      // Construction de l'URL vers notre route Go native
      final url = Uri.parse(
        '${pb.baseURL}/api/banking/institutions?country=$country',
      );
      // On passe le token de la session utilisateur pour sécuriser l'accès (Même si public pour l'instant)
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['institutions'] ?? [];
      } else {
        throw Exception(
          'Erreur API Institutions: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Impossible de charger les banques : $e');
    }
  }

  /// 2. Récupère l'URL d'autorisation (Redirect Bank URL) pour la banque choisie
  Future<String> getAuthUrl(String bankId, String redirectUrl) async {
    try {
      final url = Uri.parse('${pb.baseURL}/api/banking/auth');
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
      final url = Uri.parse('${pb.baseURL}/api/banking/callback?code=$code');
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
                'connection_id', // Pour afficher 'Banque Connectée' ou le nom
          );
      return records.map((r) => r.toJson()).toList();
    } catch (e) {
      throw Exception('Impossible de charger vos comptes bancaires liés: $e');
    }
  }

  /// 5. Lance la synchronisation API manuelle avec Enable Banking
  Future<Map<String, dynamic>> syncTransactions(
    String accountId, {
    String? dateStart,
    String? dateEnd,
  }) async {
    try {
      var urlStr = '${pb.baseURL}/api/banking/sync?account_id=$accountId';
      if (dateStart != null) urlStr += '&date_start=$dateStart';
      if (dateEnd != null) urlStr += '&date_end=$dateEnd';

      final url = Uri.parse(urlStr);
      final response = await http.get(
        url,
        headers: {'Authorization': pb.authStore.token},
      );

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
}
