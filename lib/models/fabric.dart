import 'package:cloud_firestore/cloud_firestore.dart';

class Fabric {
  final String id;
  final String name;
  final int minOrder;
  final String type;
  final String color;
  final String qualityGrade;
  final double quantity;
  final String swatchImageURL;
  final bool isUpcycled;
  final double expensePerYard;
  final DateTime createdAt;
  final DateTime updatedAt;

  Fabric({
    required this.id,
    required this.name,
    required this.minOrder,
    required this.type,
    required this.color,
    required this.qualityGrade,
    required this.quantity,
    required this.swatchImageURL,
    required this.isUpcycled,
    required this.expensePerYard,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Fabric.fromMap(String id, Map<String, dynamic> data) {
    return Fabric(
      id: id,
      name: data['name'] ?? '',
      minOrder: data['minOrder'] ?? 0,
      type: data['type'] ?? '',
      color: data['color'] ?? '',
      qualityGrade: data['qualityGrade'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      swatchImageURL: data['swatchImageURL'] ?? '',
      isUpcycled: data['isUpcycled'] ?? false,
      expensePerYard: (data['expensePerYard'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'minOrder': minOrder,
      'type': type,
      'color': color,
      'qualityGrade': qualityGrade,
      'quantity': quantity,
      'swatchImageURL': swatchImageURL,
      'isUpcycled': isUpcycled,
      'expensePerYard': expensePerYard,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
