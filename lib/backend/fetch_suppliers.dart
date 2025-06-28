import 'package:cloud_firestore/cloud_firestore.dart';

class FetchSuppliersBackend {
  /// Fetches all suppliers from the 'suppliers' collection.
  static Future<List<Map<String, dynamic>>> fetchAllSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('suppliers')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'supplierID': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching suppliers: $e');
      return [];
    }
  }

  /// Fetches a single supplier's details by supplierID.
  static Future<Map<String, dynamic>?> fetchSupplierByID(String supplierID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierID)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'supplierID': doc.id,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching supplier: $e');
      return null;
    }
  }
}