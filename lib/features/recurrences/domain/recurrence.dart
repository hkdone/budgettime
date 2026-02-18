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
      nextDueDate: DateTime.parse(record.data['next_due_date']),
      active: record.data['active'] ?? true,
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
      nextDueDate: DateTime.parse(json['next_due_date']),
      active: json['active'] ?? true,
    );
  }
}
