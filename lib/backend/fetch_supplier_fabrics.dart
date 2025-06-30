import 'package:cloud_firestore/cloud_firestore.dart';

class FetchSupplierFabricsBackend {
  /// Fetches all supplier-fabric relationships from the 'supplierFabrics' collection.
  static Future<List<Map<String, dynamic>>> fetchAllSupplierFabrics() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'supplierFabricID': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching supplier fabrics: $e');
      return [];
    }
  }

  /// Fetches supplier-fabric relationships by supplierID.
  static Future<List<Map<String, dynamic>>> fetchSupplierFabricsBySupplierID(String supplierID) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .where('supplierID', isEqualTo: supplierID)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'supplierFabricID': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching supplier fabrics by supplier ID: $e');
      return [];
    }
  }

  /// Fetches supplier-fabric relationships by fabricID.
  static Future<List<Map<String, dynamic>>> fetchSupplierFabricsByFabricID(String fabricID) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .where('fabricID', isEqualTo: fabricID)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'supplierFabricID': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching supplier fabrics by fabric ID: $e');
      return [];
    }
  }

  /// Fetches a single supplier-fabric relationship by ID.
  static Future<Map<String, dynamic>?> fetchSupplierFabricByID(String supplierFabricID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .doc(supplierFabricID)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'supplierFabricID': doc.id,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching supplier fabric by ID: $e');
      return null;
    }
  }
}
