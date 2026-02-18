import 'package:pocketbase/pocketbase.dart';

class Account {
  final String id;
  final String userId;
  final String name;
  final String type; // 'checking', 'savings', 'cash'
  final String currency;
  final double initialBalance;
  final String created;
  final String updated;

  Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.currency = 'EUR',
    this.initialBalance = 0.0,
    required this.created,
    required this.updated,
  });

  factory Account.fromRecord(RecordModel record) {
    return Account(
      id: record.id,
      userId: record.getStringValue('user'),
      name: record.getStringValue('name'),
      type: record.getStringValue('type'),
      currency: record.getStringValue('currency', 'EUR'),
      initialBalance: record.getDoubleValue('initial_balance'),
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': userId,
      'name': name,
      'type': type,
      'currency': currency,
      'initial_balance': initialBalance,
    };
  }
}
