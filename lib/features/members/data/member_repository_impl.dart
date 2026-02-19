import 'package:pocketbase/pocketbase.dart';
import '../../../../core/services/database_service.dart';
import '../domain/member.dart';
import '../domain/member_repository.dart';

class MemberRepositoryImpl implements MemberRepository {
  final DatabaseService _dbService;

  MemberRepositoryImpl(this._dbService);

  @override
  Future<List<Member>> getMembers() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    try {
      final records = await _dbService.pb
          .collection('members')
          .getFullList(filter: 'user = "${user.id}"');

      return records.map((r) => Member.fromJson(r.toJson())).toList();
    } catch (e) {
      if (e is ClientException && e.statusCode == 404) {
        // Collection doesn't exist yet or no members found
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<Member> createMember(String name, int iconCodePoint) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) throw Exception('User not logged in');

    final record = await _dbService.pb
        .collection('members')
        .create(
          body: {
            'name': name,
            'icon': iconCodePoint.toString(),
            'user': user.id,
          },
        );

    return Member.fromJson(record.toJson());
  }

  @override
  Future<void> deleteMember(String id) async {
    await _dbService.pb.collection('members').delete(id);
  }
}
