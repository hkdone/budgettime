abstract class InboxRepository {
  /// Fetch unprocessed items from raw_inbox
  Future<List<dynamic>> getUnprocessedItems();

  /// Mark an item as processed
  Future<void> markAsProcessed(String id);

  /// Mark an item as error
  Future<void> markAsError(String id, String errorMessage);
}
