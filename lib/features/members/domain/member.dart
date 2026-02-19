import 'package:flutter/material.dart';

class Member {
  final String id;
  final String name;
  final IconData icon;

  const Member({required this.id, required this.name, required this.icon});

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      name: json['name'],
      icon: IconData(
        json['icon'] != null && json['icon'].toString().isNotEmpty
            ? int.parse(json['icon'])
            : Icons.person.codePoint,
        fontFamily: 'MaterialIcons',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'icon': icon.codePoint.toString()};
  }
}
