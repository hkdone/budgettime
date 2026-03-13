abstract class InboxRepository {
  /// Fetch unprocessed items from raw_inbox
  Future<List<dynamic>> getUnprocessedItems();

  /// Mark an item as processed
  Future<void> markAsProcessed(String id);

  /// Mark an item as error
  Future<void> markAsError(String id, String errorMessage);

  /// Mark all unprocessed items as processed
  Future<void> deleteAll();

  /// S'abonner aux nouveaux items en temps réel.
  /// [onNew] est appelé avec le map de l'item (inclut 'id') à chaque création.
  Future<void> subscribe(void Function(Map<String, dynamic>) onNew);

  /// Se désabonner du flux realtime.
  Future<void> unsubscribe();
}
