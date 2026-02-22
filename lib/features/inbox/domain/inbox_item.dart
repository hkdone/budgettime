class InboxItem {
  final String id;
  final DateTime date;
  final String label;
  final double amount;
  final String user;
  final bool isProcessed;
  final String? rawPayload;
  final Map<String, dynamic>? metadata;
  final String created;
  final String updated;

  InboxItem({
    required this.id,
    required this.date,
    required this.label,
    required this.amount,
    required this.user,
    this.isProcessed = false,
    this.rawPayload,
    this.metadata,
    required this.created,
    required this.updated,
  });

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    return InboxItem(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      user: map['user'] as String,
      isProcessed: map['is_processed'] ?? false,
      rawPayload: map['raw_payload'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      created: map['created'] as String? ?? '',
      updated: map['updated'] as String? ?? '',
    );
  }
}
