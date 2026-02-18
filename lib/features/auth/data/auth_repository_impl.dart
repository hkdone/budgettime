import '../../../core/services/database_service.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DatabaseService _dbService;

  AuthRepositoryImpl(this._dbService);

  @override
  Future<void> signIn(String email, String password) async {
    await _dbService.pb.collection('users').authWithPassword(email, password);
  }

  @override
  Future<void> signUp(
    String email,
    String password,
    String confirmPassword,
  ) async {
    await _dbService.pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': confirmPassword,
          },
        );
    // Auto login after signup
    await signIn(email, password);
  }

  @override
  Future<void> signOut() async {
    _dbService.pb.authStore.clear();
  }

  @override
  bool get isAuthenticated => _dbService.isValid;

  @override
  String? get currentUserId => _dbService.userId;
}
