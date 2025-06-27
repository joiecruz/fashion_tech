import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductBackend {
  /// Updates all fields of a product document in Firestore.
  /// [productID] is the document ID of the product to update.
  /// [updatedData] is a map of all fields to update.
  static Future<void> updateProduct({
    required String productID,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productID)
          .update(updatedData);
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