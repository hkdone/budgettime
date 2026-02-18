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
  /// In development, ensuring your PocketBase server is running on 127.0.0.1:8090.
  /// When deployed in `pb_public`, this should ideally be relative or the same origin.
  /// Parsing `window.location` requires distinct handling for web vs mobile.
  /// Using a relative path "/" often works fine if served from same origin (which is our case with pb_public).

  // ignore: unnecessary_const
  final PocketBase pb = PocketBase(
    const bool.fromEnvironment('dart.library.js_util')
        ? '/'
        : 'http://127.0.0.1:8090',
  );

  /// Returns true if the user is currently authenticated
  bool get isValid => pb.authStore.isValid;

  /// Returns the current authenticated user id or null
  String? get userId => pb.authStore.record?.id;
}

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);
