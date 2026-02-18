import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authRepositoryProvider).signIn(email, password);
    });
  }

  Future<void> signUp(
    String email,
    String password,
    String confirmPassword,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(authRepositoryProvider)
          .signUp(email, password, confirmPassword);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(authRepositoryProvider).signOut();
    });
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref);
    });
