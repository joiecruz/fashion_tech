import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_log.dart';

/// Service for managing sales logs and transaction logs
class SalesLogService {
  static const String _collection = 'salesLogs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new sales log entry
  static Future<String> createSalesLog(SalesLog log) async {
    try {
      final docRef = await _firestore.collection(_collection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating sales log: $e');
      rethrow;
    }
  }

  /// Log a product sale transaction
  static Future<void> logSale({
    required String productID,
    required String variantID,
    required int qtySold,
    required double sellingPrice,
    String? transactionId,
    String? customerInfo,
    String? notes,
  }) async {
    final totalRevenue = qtySold * sellingPrice;
    
    final log = SalesLog(
      id: '', // Will be set by Firestore
      productID: productID,
      variantID: variantID,
      qtySold: qtySold,
      sellingPrice: sellingPrice,
      dateSold: DateTime.now(),
      totalRevenue: totalRevenue,
    );
    await createSalesLog(log);
  }

  /// Get all sales logs for a specific product
  static Future<List<SalesLog>> getProductSales(String productID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productID', isEqualTo: productID)
          .orderBy('dateSold', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SalesLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching product sales: $e');
      return [];
    }
  }

  /// Get all sales logs for a specific variant
  static Future<List<SalesLog>> getVariantSales(String variantID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('variantID', isEqualTo: variantID)
          .orderBy('dateSold', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SalesLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching variant sales: $e');
      return [];
    }
  }

  /// Get sales within a date range
  static Future<List<SalesLog>> getSalesInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('dateSold', isGreaterThanOrEqualTo: startDate)
          .where('dateSold', isLessThanOrEqualTo: endDate)
          .orderBy('dateSold', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SalesLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching sales in date range: $e');
      return [];
    }
  }

  /// Get all sales logs with pagination
  static Future<List<SalesLog>> getAllSalesLogs({
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('dateSold', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => SalesLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all sales logs: $e');
      return [];
    }
  }

  /// Calculate total revenue for a product
  static Future<double> getProductTotalRevenue(String productID) async {
    try {
      final salesLogs = await getProductSales(productID);
      return salesLogs.fold<double>(0.0, (total, log) => total + log.totalRevenue);
    } catch (e) {
      print('Error calculating product total revenue: $e');
      return 0.0;
    }
  }

  /// Calculate total revenue for a date range
  static Future<double> getTotalRevenueInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesLogs = await getSalesInDateRange(
        startDate: startDate,
        endDate: endDate,
      );
      return salesLogs.fold<double>(0.0, (total, log) => total + log.totalRevenue);
    } catch (e) {
      print('Error calculating total revenue in date range: $e');
      return 0.0;
    }
  }

  /// Stream of sales logs for real-time updates
  static Stream<List<SalesLog>> streamProductSales(String productID) {
    return _firestore
        .collection(_collection)
        .where('productID', isEqualTo: productID)
        .orderBy('dateSold', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SalesLog.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Delete all sales logs for a product (used when product is permanently deleted)
  static Future<void> deleteProductSalesLogs(String productID) async {
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
      print('Error deleting product sales logs: $e');
    }
  }
}
