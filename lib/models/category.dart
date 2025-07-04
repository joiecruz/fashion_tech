import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryType { product, fabric, expense }

class Category {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final CategoryType type;

  Category({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.type,
  });

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      type: _typeFromString(data['type'] ?? 'product'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'type': _typeToString(type),
    };
  }

  static CategoryType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'product':
        return CategoryType.product;
      case 'fabric':
        return CategoryType.fabric;
      case 'expense':
        return CategoryType.expense;
      default:
        return CategoryType.product;
    }
  }

  static String _typeToString(CategoryType type) {
    switch (type) {
      case CategoryType.product:
        return 'product';
      case CategoryType.fabric:
        return 'fabric';
      case CategoryType.expense:
        return 'expense';
    }
  }
}
