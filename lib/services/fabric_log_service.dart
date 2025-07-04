import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fabric_log.dart';

class FabricLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'fabricLogs';

  /// Create a fabric log entry
  static Future<String> createFabricLog(FabricLog fabricLog) async {
    try {
      final docRef = await _firestore.collection(_collection).add(fabricLog.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating fabric log: $e');
      rethrow;
    }
  }

  /// Create a log for adding new fabric
  static Future<void> logFabricAdd({
    required String fabricID,
    required double quantity,
    required String createdBy,
    String? remarks,
  }) async {
    final log = FabricLog(
      id: '', // Will be set by Firestore
      fabricID: fabricID,
      changeType: FabricChangeType.add,
      quantityChanged: quantity,
      source: FabricLogSource.manual,
      remarks: remarks ?? 'Initial fabric added',
      logDate: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    await createFabricLog(log);
  }

  /// Create a log for editing fabric quantity
  static Future<void> logFabricEdit({
    required String fabricID,
    required double oldQuantity,
    required double newQuantity,
    required String createdBy,
    String? remarks,
  }) async {
    final quantityDifference = newQuantity - oldQuantity;
    
    if (quantityDifference != 0) {
      final log = FabricLog(
        id: '', // Will be set by Firestore
        fabricID: fabricID,
        changeType: quantityDifference > 0 ? FabricChangeType.add : FabricChangeType.deduct,
        quantityChanged: quantityDifference.abs(),
        source: FabricLogSource.manual,
        remarks: remarks ?? 'Fabric quantity ${quantityDifference > 0 ? 'increased' : 'decreased'} via edit',
        logDate: DateTime.now(),
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );
      await createFabricLog(log);
    }
  }

  /// Create a log for deleting fabric
  static Future<void> logFabricDelete({
    required String fabricID,
    required double quantity,
    required String createdBy,
    String? remarks,
  }) async {
    final log = FabricLog(
      id: '', // Will be set by Firestore
      fabricID: fabricID,
      changeType: FabricChangeType.deduct,
      quantityChanged: quantity,
      source: FabricLogSource.manual,
      remarks: remarks ?? 'Fabric deleted from inventory',
      logDate: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    await createFabricLog(log);
  }

  /// Get all logs for a specific fabric
  static Future<List<FabricLog>> getFabricLogs(String fabricID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('fabricID', isEqualTo: fabricID)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => FabricLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching fabric logs: $e');
      return [];
    }
  }

  /// Get recent logs for a specific fabric (limit to most recent)
  static Future<List<FabricLog>> getRecentFabricLogs(String fabricID, {int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('fabricID', isEqualTo: fabricID)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => FabricLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching recent fabric logs: $e');
      return [];
    }
  }

  /// Get all fabric logs with pagination
  static Future<List<FabricLog>> getAllFabricLogs({
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
          .map((doc) => FabricLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all fabric logs: $e');
      return [];
    }
  }

  /// Stream of fabric logs for real-time updates
  static Stream<List<FabricLog>> streamFabricLogs(String fabricID) {
    return _firestore
        .collection(_collection)
        .where('fabricID', isEqualTo: fabricID)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FabricLog.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Delete all logs for a fabric (used when fabric is permanently deleted)
  static Future<void> deleteFabricLogs(String fabricID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('fabricID', isEqualTo: fabricID)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting fabric logs: $e');
    }
  }
}
