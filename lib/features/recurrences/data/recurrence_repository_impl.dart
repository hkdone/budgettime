import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/database_service.dart';
import '../domain/recurrence.dart';
import '../domain/recurrence_repository.dart';

class RecurrenceRepositoryImpl implements RecurrenceRepository {
  final DatabaseService _dbService;

  RecurrenceRepositoryImpl(this._dbService);

  @override
  Future<List<Recurrence>> getRecurrences() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    final records = await _dbService.pb
        .collection('recurrences')
        .getFullList(filter: 'user = "${user.id}"', sort: 'next_due_date');

    return records.map((record) => Recurrence.fromRecord(record)).toList();
  }

  @override
  Future<Recurrence?> addRecurrence(Map<String, dynamic> data) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return null;

    try {
      final record = await _dbService.pb
          .collection('recurrences')
          .create(body: {'user': user.id, ...data});
      return Recurrence.fromRecord(record);
    } on ClientException catch (e) {
      throw Exception('Failed to add recurrence: ${e.response}');
    }
  }

  @override
  Future<void> updateRecurrence(String id, Map<String, dynamic> data) async {
    try {
      await _dbService.pb.collection('recurrences').update(id, body: data);
    } on ClientException catch (e) {
      throw Exception('Failed to update recurrence: ${e.response}');
    }
  }

  @override
  Future<void> deleteRecurrence(String id) async {
    try {
      await _dbService.pb.collection('recurrences').delete(id);
    } on ClientException catch (e) {
      throw Exception('Failed to delete recurrence: ${e.response}');
    }
  }
}

final recurrenceRepositoryProvider = Provider<RecurrenceRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return RecurrenceRepositoryImpl(dbService);
});
