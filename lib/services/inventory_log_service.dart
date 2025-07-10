import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_log.dart';

/// Service for managing inventory/product logs
class InventoryLogService {
  static const String _collection = 'inventoryLogs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new inventory log entry
  static Future<String> createInventoryLog(InventoryLog log) async {
    try {
      final docRef = await _firestore.collection(_collection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating inventory log: $e');
      rethrow;
    }
  }

  /// Log adding inventory/products
  static Future<void> logInventoryAdd({
    required String productID,
    required String supplierID,
    required int quantityAdded,
    required String createdBy,
    String? remarks,
  }) async {
    final log = InventoryLog(
      id: '', // Will be set by Firestore
      productID: productID,
      supplierID: supplierID,
      createdBy: createdBy,
      changeType: InventoryChangeType.add,
      quantityChanged: quantityAdded,
      remarks: remarks ?? 'Inventory added',
      createdAt: DateTime.now(),
    );
    await createInventoryLog(log);
  }

  /// Log deducting inventory/products
  static Future<void> logInventoryDeduct({
    required String productID,
    required String supplierID,
    required int quantityDeducted,
    required String createdBy,
    String? remarks,
  }) async {
    final log = InventoryLog(
      id: '', // Will be set by Firestore
      productID: productID,
      supplierID: supplierID,
      createdBy: createdBy,
      changeType: InventoryChangeType.deduct,
      quantityChanged: quantityDeducted,
      remarks: remarks ?? 'Inventory deducted',
      createdAt: DateTime.now(),
    );
    await createInventoryLog(log);
  }

  /// Log inventory correction
  static Future<void> logInventoryCorrection({
    required String productID,
    required String supplierID,
    required int quantityDifference,
    required String createdBy,
    String? remarks,
  }) async {
    final log = InventoryLog(
      id: '', // Will be set by Firestore
      productID: productID,
      supplierID: supplierID,
      createdBy: createdBy,
      changeType: InventoryChangeType.correction,
      quantityChanged: quantityDifference.abs(),
      remarks: remarks ?? 'Inventory correction: ${quantityDifference > 0 ? 'increased' : 'decreased'} by ${quantityDifference.abs()}',
      createdAt: DateTime.now(),
    );
    await createInventoryLog(log);
  }

  /// Get all logs for a specific product
  static Future<List<InventoryLog>> getProductLogs(String productID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productID', isEqualTo: productID)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => InventoryLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching product logs: $e');
      return [];
    }
  }

  /// Get all logs for a specific supplier
  static Future<List<InventoryLog>> getSupplierLogs(String supplierID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('supplierID', isEqualTo: supplierID)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => InventoryLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching supplier logs: $e');
      return [];
    }
  }

  /// Get all inventory logs with pagination
  static Future<List<InventoryLog>> getAllInventoryLogs({
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => InventoryLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all inventory logs: $e');
      return [];
    }
  }

  /// Stream of inventory logs for real-time updates
  static Stream<List<InventoryLog>> streamProductLogs(String productID) {
    return _firestore
        .collection(_collection)
        .where('productID', isEqualTo: productID)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryLog.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Delete all logs for a product (used when product is permanently deleted)
  static Future<void> deleteProductLogs(String productID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productID', isEqualTo: productID)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting product logs: $e');
    }
  }
}
