import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String fullName;
  final String contactNum;
  final String? address;
  final String? email;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.fullName,
    required this.contactNum,
    this.address,
    this.email,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> data) {
    return Customer(
      id: id,
      fullName: data['fullName'] ?? '',
      contactNum: data['contactNum'] ?? '',
      address: data['address'],
      email: data['email'],
      notes: data['notes'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'contactNum': contactNum,
      'address': address,
      'email': email,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
