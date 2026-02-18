import 'recurrence.dart';

abstract class RecurrenceRepository {
  Future<List<Recurrence>> getRecurrences();
  Future<Recurrence?> addRecurrence(Map<String, dynamic> data);
  Future<void> updateRecurrence(String id, Map<String, dynamic> data);
  Future<void> deleteRecurrence(String id);
}
