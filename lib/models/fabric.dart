import 'package:cloud_firestore/cloud_firestore.dart';

class Fabric {
  final String id;
  final String name;
  final String type;
  final String color;
  final String qualityGrade;
  final double quantity; // in yards
  final double expensePerYard;
  final String? swatchImageURL;
  final DateTime createdAt;
  final DateTime updatedAt;

  Fabric({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.qualityGrade,
    required this.quantity,
    required this.expensePerYard,
    this.swatchImageURL,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Fabric.fromMap(String id, Map<String, dynamic> data) {
    return Fabric(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      color: data['color'] ?? '',
      qualityGrade: data['qualityGrade'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      expensePerYard: (data['expensePerYard'] ?? 0).toDouble(),
      swatchImageURL: data['swatchImageURL'],
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
      'type': type,
      'color': color,
      'qualityGrade': qualityGrade,
      'quantity': quantity,
      'expensePerYard': expensePerYard,
      'swatchImageURL': swatchImageURL,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
