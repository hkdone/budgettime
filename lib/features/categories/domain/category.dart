import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSystem;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isSystem = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: IconData(json['icon_code_point'], fontFamily: 'MaterialIcons'),
      color: Color(int.parse(json['color_hex'], radix: 16)),
      isSystem: json['is_system'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon_code_point': icon.codePoint,
      // ignore: deprecated_member_use
      'color_hex': color.value.toRadixString(16),
      'is_system': isSystem,
    };
  }
}
