import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class to interact with PocketBase backend.
/// Designed to be a Singleton.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal() {
    // Basic setup in constructor, loading is async in init()
  }

  final PocketBase pb = PocketBase(
    const bool.fromEnvironment('dart.library.js_util')
        ? '/'
        : 'http://127.0.0.1:8090',
  );

  /// Initializes the persistence for the AuthStore.
  /// Should be called at app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load existing session
    final authData = prefs.getString('pb_auth');
    if (authData != null) {
      try {
        final decoded = jsonDecode(authData);
        final token = decoded['token'] as String;
        final recordJson =
            (decoded['record'] ?? decoded['model']) as Map<String, dynamic>;
        final record = RecordModel.fromJson(recordJson);
        pb.authStore.save(token, record);
      } catch (e) {
        // ignore: avoid_print
        print('Error loading auth state: $e');
        pb.authStore.clear();
      }
    }

    // 2. Listen for changes and save them
    pb.authStore.onChange.listen((e) {
      if (pb.authStore.isValid) {
        final data = jsonEncode({
          'token': pb.authStore.token,
          'record': pb.authStore.record,
        });
        prefs.setString('pb_auth', data);
      } else {
        prefs.remove('pb_auth');
      }
    });
  }

  /// Returns true if the user is currently authenticated
  bool get isValid => pb.authStore.isValid;

  /// Returns the current authenticated user id or null
  String? get userId => pb.authStore.record?.id;
}

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);
