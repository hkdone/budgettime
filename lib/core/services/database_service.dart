import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service class to interact with PocketBase backend.
/// Designed to be a Singleton.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// The PocketBase client instance.
  ///
  /// In development, ensuring your PocketBase server is running on 127.0.0.1:8095.
  /// When deployed in `pb_public`, this should ideally be relative or the same origin.
  /// Passing `http://127.0.0.1:8090` works for local dev and often for same-machine access if CORS is handled.
  final PocketBase pb = PocketBase('http://127.0.0.1:8090');

  /// Returns true if the user is currently authenticated
  bool get isValid => pb.authStore.isValid;

  /// Returns the current authenticated user id or null
  String? get userId => pb.authStore.record?.id;
}

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);
