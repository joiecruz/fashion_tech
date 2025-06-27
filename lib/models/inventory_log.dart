import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryChangeType { add, deduct, correction }

class InventoryLog {
  final String id;
  final String productID;
  final String supplierID;
  final String createdBy;
  final InventoryChangeType changeType;
  final int quantityChanged;
  final String? remarks;
  final DateTime createdAt;

  InventoryLog({
    required this.id,
    required this.productID,
    required this.supplierID,
    required this.createdBy,
    required this.changeType,
    required this.quantityChanged,
    this.remarks,
    required this.createdAt,
  });

  factory InventoryLog.fromMap(String id, Map<String, dynamic> data) {
    return InventoryLog(
      id: id,
      productID: data['productID'] ?? '',
      supplierID: data['supplierID'] ?? '',
      createdBy: data['createdBy'] ?? '',
      changeType: _changeTypeFromString(data['changeType'] ?? 'add'),
      quantityChanged: data['quantityChanged'] ?? 0,
      remarks: data['remarks'],
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'supplierID': supplierID,
      'createdBy': createdBy,
      'changeType': _changeTypeToString(changeType),
      'quantityChanged': quantityChanged,
      'remarks': remarks,
      'createdAt': createdAt,
    };
  }

  static InventoryChangeType _changeTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'add':
        return InventoryChangeType.add;
      case 'deduct':
        return InventoryChangeType.deduct;
      case 'correction':
        return InventoryChangeType.correction;
      default:
        return InventoryChangeType.add;
    }
  }

  static String _changeTypeToString(InventoryChangeType type) {
    switch (type) {
      case InventoryChangeType.add:
        return 'add';
      case InventoryChangeType.deduct:
        return 'deduct';
      case InventoryChangeType.correction:
        return 'correction';
    }
  }
}
