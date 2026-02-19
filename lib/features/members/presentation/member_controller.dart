import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/start_app.dart';
import '../domain/member.dart';

final memberControllerProvider =
    StateNotifierProvider<MemberController, AsyncValue<List<Member>>>((ref) {
      return MemberController(ref);
    });

class MemberController extends StateNotifier<AsyncValue<List<Member>>> {
  final Ref _ref;

  MemberController(this._ref) : super(const AsyncValue.loading()) {
    loadMembers();
  }

  Future<void> loadMembers() async {
    try {
      state = const AsyncValue.loading();
      final repository = _ref.read(memberRepositoryProvider);
      final members = await repository.getMembers();
      state = AsyncValue.data(members);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMember(String name, int iconCodePoint) async {
    try {
      final repository = _ref.read(memberRepositoryProvider);
      await repository.createMember(name, iconCodePoint);
      await loadMembers();
    } catch (e) {
      // Handle error (maybe show snackbar via listener in UI)
      rethrow;
    }
  }

  Future<void> deleteMember(String id) async {
    try {
      final repository = _ref.read(memberRepositoryProvider);
      await repository.deleteMember(id);
      await loadMembers(); // Refresh list
    } catch (e) {
      rethrow;
    }
  }
}
