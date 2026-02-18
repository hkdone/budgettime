abstract class AuthRepository {
  /// Sign in with email and password
  Future<void> signIn(String email, String password);

  /// Sign up with email and password
  Future<void> signUp(String email, String password, String confirmPassword);

  /// Sign out the current user
  Future<void> signOut();

  /// Check if user is currently authenticated
  bool get isAuthenticated;

  /// Get current user ID
  String? get currentUserId;
}
