import 'member.dart';

abstract class MemberRepository {
  Future<List<Member>> getMembers();
  Future<Member> createMember(String name, int iconCodePoint);
  Future<void> deleteMember(String id);
}
