import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductBackend {
  /// Updates all fields of a product document in Firestore.
  /// [productID] is the document ID of the product to update.
  /// [updatedData] is a map of all fields to update.
  static Future<void> updateProduct({
    required String productID,
    required Map<String, dynamic> updatedData,
  }) async {
    // Convert any DateTime/String/Timestamp fields to Timestamp for Firestore compatibility
    final Map<String, dynamic> dataToUpdate = Map.from(updatedData);

    Timestamp? _toTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return Timestamp.fromDate(dt);
      }
      return null;
    }

    if (dataToUpdate['createdAt'] != null) {
      dataToUpdate['createdAt'] = _toTimestamp(dataToUpdate['createdAt']);
    }
    if (dataToUpdate['updatedAt'] != null) {
      dataToUpdate['updatedAt'] = _toTimestamp(dataToUpdate['updatedAt']);
    }

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productID)
          .update(dataToUpdate);
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  /// Updates all fields of a product variant document in Firestore.
  /// [variantID] is the document ID of the variant to update.
  /// [updatedData] is a map of all fields to update.
  static Future<void> updateVariant({
    required String variantID,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('productVariants')
          .doc(variantID)
          .update(updatedData);
    } catch (e) {
      print('Error updating variant: $e');
      rethrow;
    }
  }
}