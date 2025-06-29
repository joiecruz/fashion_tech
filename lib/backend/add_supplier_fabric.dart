import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSupplierFabricBackend {
  /// Creates a new supplier-fabric relationship in the 'supplier_fabrics' collection.
  /// 
  /// This establishes a relationship between a supplier and a fabric, including
  /// supply pricing and delivery information.
  static Future<String> addSupplierFabric({
    required String supplierID,
    required String fabricID,
    required double supplyPrice,
    int? minOrder,
    int? daysToDeliver,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      final docRef = await FirebaseFirestore.instance
          .collection('supplier_fabrics')
          .add({
        'supplierID': supplierID,
        'fabricID': fabricID,
        'supplyPrice': supplyPrice,
        'minOrder': minOrder,
        'daysToDeliver': daysToDeliver,
        'createdBy': currentUser?.uid ?? 'anonymous', // ERDv8 requirement
        'createdAt': Timestamp.now(),
      });

      print('Supplier-fabric relationship created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating supplier-fabric relationship: $e');
      rethrow;
    }
  }

  /// Updates an existing supplier-fabric relationship.
  static Future<void> updateSupplierFabric({
    required String supplierFabricID,
    double? supplyPrice,
    int? minOrder,
    int? daysToDeliver,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      Map<String, dynamic> updates = {
        'updatedBy': currentUser?.uid ?? 'anonymous',
        'updatedAt': Timestamp.now(),
      };

      if (supplyPrice != null) updates['supplyPrice'] = supplyPrice;
      if (minOrder != null) updates['minOrder'] = minOrder;
      if (daysToDeliver != null) updates['daysToDeliver'] = daysToDeliver;

      await FirebaseFirestore.instance
          .collection('supplier_fabrics')
          .doc(supplierFabricID)
          .update(updates);

      print('Supplier-fabric relationship updated: $supplierFabricID');
    } catch (e) {
      print('Error updating supplier-fabric relationship: $e');
      rethrow;
    }
  }

  /// Removes a supplier-fabric relationship (soft delete).
  static Future<void> removeSupplierFabric(String supplierFabricID) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance
          .collection('supplier_fabrics')
          .doc(supplierFabricID)
          .update({
        'deletedBy': currentUser?.uid ?? 'anonymous',
        'deletedAt': Timestamp.now(),
      });

      print('Supplier-fabric relationship removed: $supplierFabricID');
    } catch (e) {
      print('Error removing supplier-fabric relationship: $e');
      rethrow;
    }
  }

  /// Checks if a supplier-fabric relationship already exists.
  static Future<String?> findExistingRelationship({
    required String supplierID,
    required String fabricID,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supplier_fabrics')
          .where('supplierID', isEqualTo: supplierID)
          .where('fabricID', isEqualTo: fabricID)
          .where('deletedAt', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error checking existing supplier-fabric relationship: $e');
      return null;
    }
  }
}
