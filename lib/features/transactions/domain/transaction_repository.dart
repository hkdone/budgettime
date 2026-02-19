abstract class TransactionRepository {
  /// Fetch transactions for a specific period
  Future<List<Map<String, dynamic>>> getTransactions({
    required DateTime start,
    required DateTime end,
    String? accountId,
  });

  /// Fetch projected transactions strictly before a certain date
  Future<List<Map<String, dynamic>>> getOverdueProjectedTransactions({
    required DateTime beforeDate,
    String? accountId,
  });

  Future<double> getBalance({
    String? accountId,
    String? status,
    DateTime? maxDate,
  });

  /// Add a new transaction
  Future<void> addTransaction(Map<String, dynamic> data);

  /// Update an existing transaction
  Future<void> updateTransaction(String id, Map<String, dynamic> data);

  /// Delete a transaction
  Future<void> deleteTransaction(String id);

  /// Delete a transaction and all future projected transactions linked to the same recurrence
  Future<void> deleteFutureTransactions(String recurrenceId, DateTime fromDate);

  /// Update a transaction and all future projected transactions linked to the same recurrence
  Future<void> updateFutureTransactions(
    String recurrenceId,
    DateTime fromDate,
    Map<String, dynamic> data,
  );
}
