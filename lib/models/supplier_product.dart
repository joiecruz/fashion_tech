import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierProduct {
  final String id;
  final String supplierID;
  final String productID;
  final double supplyPrice;
  final int? minOrderQty;
  final int? daysToDeliver; // renamed from leadTimeDays
  final DateTime createdAt;

  SupplierProduct({
    required this.id,
    required this.supplierID,
    required this.productID,
    required this.supplyPrice,
    this.minOrderQty,
    this.daysToDeliver,
    required this.createdAt,
  });

  factory SupplierProduct.fromMap(String id, Map<String, dynamic> data) {
    return SupplierProduct(
      id: id,
      supplierID: data['supplierID'] ?? '',
      productID: data['productID'] ?? '',
      supplyPrice: (data['supplyPrice'] ?? 0).toDouble(),
      minOrderQty: data['minOrderQty'],
      daysToDeliver: data['daysToDeliver'] ?? data['leadTimeDays'], // support both for migration
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierID': supplierID,
      'productID': productID,
      'supplyPrice': supplyPrice,
      'minOrderQty': minOrderQty,
      'daysToDeliver': daysToDeliver,
      'createdAt': createdAt,
    };
  }
}
