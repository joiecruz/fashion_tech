import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fabric_log.dart';
import 'fabric_log_service.dart';

class FabricOperationsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _fabricsCollection = 'fabrics';

  /// Add a new fabric with logging
  static Future<String> addFabric({
    required Map<String, dynamic> fabricData,
    required String createdBy,
    String? remarks,
  }) async {
    try {
      // Add fabric to Firestore
      final docRef = await _firestore.collection(_fabricsCollection).add(fabricData);
      final fabricId = docRef.id;
      
      // Log the fabric addition
      await FabricLogService.logFabricAdd(
        fabricID: fabricId,
        quantity: (fabricData['quantity'] ?? 0).toDouble(),
        createdBy: createdBy,
        remarks: remarks ?? 'Initial fabric added to inventory',
      );
      
      return fabricId;
    } catch (e) {
      print('Error adding fabric: $e');
      rethrow;
    }
  }

  /// Update fabric with logging
  static Future<void> updateFabric({
    required String fabricId,
    required Map<String, dynamic> updatedData,
    required String updatedBy,
    String? remarks,
  }) async {
    try {
      // Get current fabric data for comparison
      final currentDoc = await _firestore.collection(_fabricsCollection).doc(fabricId).get();
      final currentData = currentDoc.data();
      
      if (currentData != null) {
        final oldQuantity = (currentData['quantity'] ?? 0).toDouble();
        final newQuantity = (updatedData['quantity'] ?? 0).toDouble();
        
        // Update the fabric
        await _firestore.collection(_fabricsCollection).doc(fabricId).update(updatedData);
        
        // Log the fabric edit if quantity changed
        if (oldQuantity != newQuantity) {
          await FabricLogService.logFabricEdit(
            fabricID: fabricId,
            oldQuantity: oldQuantity,
            newQuantity: newQuantity,
            createdBy: updatedBy,
            remarks: remarks ?? 'Fabric quantity updated via edit',
          );
        }
      }
    } catch (e) {
      print('Error updating fabric: $e');
      rethrow;
    }
  }

  /// Delete fabric with logging
  static Future<void> deleteFabric({
    required String fabricId,
    required String deletedBy,
    String? remarks,
  }) async {
    try {
      // Get fabric data before deletion for logging
      final fabricDoc = await _firestore.collection(_fabricsCollection).doc(fabricId).get();
      final fabricData = fabricDoc.data();
      
      if (fabricData != null) {
        final quantity = (fabricData['quantity'] ?? 0).toDouble();
        
        // Log the fabric deletion
        await FabricLogService.logFabricDelete(
          fabricID: fabricId,
          quantity: quantity,
          createdBy: deletedBy,
          remarks: remarks ?? 'Fabric deleted from inventory',
        );
      }
      
      // Delete the fabric
      await _firestore.collection(_fabricsCollection).doc(fabricId).delete();
      
    } catch (e) {
      print('Error deleting fabric: $e');
      rethrow;
    }
  }

  /// Adjust fabric quantity with logging
  static Future<void> adjustFabricQuantity({
    required String fabricId,
    required double quantityChange,
    required String adjustedBy,
    required String source, // 'manual', 'jobOrder', 'adjustment'
    String? remarks,
  }) async {
    try {
      // Get current fabric data
      final fabricDoc = await _firestore.collection(_fabricsCollection).doc(fabricId).get();
      final fabricData = fabricDoc.data();
      
      if (fabricData != null) {
        final currentQuantity = (fabricData['quantity'] ?? 0).toDouble();
        final newQuantity = currentQuantity + quantityChange;
        
        // Ensure quantity doesn't go negative
        if (newQuantity < 0) {
          throw Exception('Insufficient fabric quantity. Current: $currentQuantity, Requested: ${quantityChange.abs()}');
        }
        
        // Update fabric quantity
        await _firestore.collection(_fabricsCollection).doc(fabricId).update({
          'quantity': newQuantity,
          'lastEdited': Timestamp.now(),
        });
        
        // Create fabric log
        final log = FabricLog(
          id: '', // Will be set by Firestore
          fabricID: fabricId,
          changeType: quantityChange > 0 ? FabricChangeType.add : FabricChangeType.deduct,
          quantityChanged: quantityChange.abs(),
          source: _getSourceFromString(source),
          remarks: remarks,
          logDate: DateTime.now(),
          createdAt: DateTime.now(),
          createdBy: adjustedBy,
        );
        
        await FabricLogService.createFabricLog(log);
      }
    } catch (e) {
      print('Error adjusting fabric quantity: $e');
      rethrow;
    }
  }

  /// Helper method to convert string to FabricLogSource
  static FabricLogSource _getSourceFromString(String source) {
    switch (source.toLowerCase()) {
      case 'manual':
        return FabricLogSource.manual;
      case 'joborder':
        return FabricLogSource.jobOrder;
      case 'adjustment':
        return FabricLogSource.adjustment;
      default:
        return FabricLogSource.manual;
    }
  }

  /// Get fabric with recent log for display
  static Future<Map<String, dynamic>?> getFabricWithRecentLog(String fabricId) async {
    try {
      final fabricDoc = await _firestore.collection(_fabricsCollection).doc(fabricId).get();
      final fabricData = fabricDoc.data();
      
      if (fabricData != null) {
        fabricData['id'] = fabricId;
        
        // Get most recent log
        final recentLogs = await FabricLogService.getRecentFabricLogs(fabricId, limit: 1);
        if (recentLogs.isNotEmpty) {
          fabricData['recentLog'] = recentLogs.first;
        }
        
        return fabricData;
      }
      return null;
    } catch (e) {
      print('Error getting fabric with recent log: $e');
      return null;
    }
  }
}
