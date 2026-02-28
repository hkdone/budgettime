class Recurrence {
  final String id;
  final String accountId;
  final double amount;
  final String label;
  final String type; // income, expense, transfer
  final String frequency; // daily, weekly, monthly, yearly
  final int? dayOfMonth;
  final DateTime nextDueDate;
  final bool active;
  final String? targetAccountId;
  final String? memberId;
  final String? categoryId;

  Recurrence({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.label,
    required this.type,
    required this.frequency,
    this.dayOfMonth,
    required this.nextDueDate,
    required this.active,
    this.targetAccountId,
    this.memberId,
    this.categoryId,
  });

  factory Recurrence.fromRecord(dynamic record) {
    return Recurrence(
      id: record.id,
      accountId: record.data['account'],
      amount: (record.data['amount'] as num).toDouble(),
      label: record.data['label'],
      type: record.data['type'],
      frequency: record.data['frequency'],
      dayOfMonth: record.data['day_of_month'],
      nextDueDate: DateTime.parse(record.data['next_due_date']).toLocal(),
      active: record.data['active'] ?? true,
      targetAccountId: record.data['target_account'],
      memberId: record.data['member'],
      categoryId: record.data['category']?.toString().isNotEmpty == true
          ? record.data['category']
          : (record.expand['category'] != null
                ? (record.expand['category'] is List
                      ? (record.expand['category'] as List).firstOrNull?.id
                      : record.expand['category']?.id)
                : null),
    );
  }

  factory Recurrence.fromJson(Map<String, dynamic> json) {
    return Recurrence(
      id: json['id'],
      accountId: json['account'],
      amount: (json['amount'] as num).toDouble(),
      label: json['label'],
      type: json['type'],
      frequency: json['frequency'],
      dayOfMonth: json['day_of_month'],
      nextDueDate: DateTime.parse(json['next_due_date']).toLocal(),
      active: json['active'] ?? true,
      targetAccountId: json['target_account'],
      memberId: json['member'],
      categoryId: json['category']?.toString().isNotEmpty == true
          ? json['category']
          : json['expand']?['category']?['id'],
    );
  }
}
