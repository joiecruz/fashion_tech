import 'package:cloud_firestore/cloud_firestore.dart';

class FetchVariantsBackend {
  static Future<List<Map<String, dynamic>>> fetchVariantsByProductID(String productID) async {
    try {
      final variantsSnapshot = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: productID)
          .get();

      return variantsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'variantID': doc.id,
          'size': data['size'] ?? '',
          'color': data['color'] ?? '',
          'quantityInStock': data['quantityInStock'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching variants: $e');
      return [];
    }
  }
}