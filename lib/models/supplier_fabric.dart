import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierFabric {
  final String id;
  final String supplierID;
  final String fabricID;
  final double supplyPrice; // per yard
  final int? minOrder;
  final int? daysToDeliver;
  final String createdBy; // New field in ERDv8
  final DateTime createdAt;

  SupplierFabric({
    required this.id,
    required this.supplierID,
    required this.fabricID,
    required this.supplyPrice,
    this.minOrder,
    this.daysToDeliver,
    required this.createdBy,
    required this.createdAt,
  });

  factory SupplierFabric.fromMap(String id, Map<String, dynamic> data) {
    return SupplierFabric(
      id: id,
      supplierID: data['supplierID'] ?? '',
      fabricID: data['fabricID'] ?? '',
      supplyPrice: (data['supplyPrice'] ?? 0).toDouble(),
      minOrder: data['minOrder'],
      daysToDeliver: data['daysToDeliver'],
      createdBy: data['createdBy'] ?? 'anonymous',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierID': supplierID,
      'fabricID': fabricID,
      'supplyPrice': supplyPrice,
      'minOrder': minOrder,
      'daysToDeliver': daysToDeliver,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
