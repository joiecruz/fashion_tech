import 'package:cloud_firestore/cloud_firestore.dart';

class SellBackend {
  /// Sells [quantity] of a specific [variantId] at [pricePerItem].
  /// Logs the sale in SALESLOG and updates PRODUCTVARIANT stock.
  static Future<void> sellProductVariant({
    required String productId,
    required String variantId,
    required int quantity,
    required double pricePerItem,
    String? userId,
  }) async {
    final variantRef = FirebaseFirestore.instance.collection('productVariants').doc(variantId);
    final productRef = FirebaseFirestore.instance.collection('products').doc(productId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final variantSnap = await transaction.get(variantRef);
      if (!variantSnap.exists) throw Exception('Variant not found');
      final currentStock = variantSnap['quantityInStock'] ?? 0;
      if (currentStock < quantity) throw Exception('Not enough stock in variant');

      // Deduct stock from variant
      transaction.update(variantRef, {
        'quantityInStock': currentStock - quantity,
      });

      // Optionally, update product's total stock (sum of all variants)
      final variantsQuery = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: productId)
          .get();
      final totalStock = variantsQuery.docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc.id == variantId)
            ? (((doc['quantityInStock'] ?? 0) as int) - quantity)
            : ((doc['quantityInStock'] ?? 0) as int)),
      );
      transaction.update(productRef, {
        'stock': totalStock,
        'updatedAt': DateTime.now(),
      });

      // Log the sale in SALESLOG
      final salesLogRef = FirebaseFirestore.instance.collection('salesLog').doc();
      transaction.set(salesLogRef, {
        'salesLogID': salesLogRef.id,
        'productID': productId,
        'variantID': variantId,
        'qtySold': quantity,
        'sellingPrice': pricePerItem,
        'dateSold': DateTime.now(),
        'totalRevenue': pricePerItem * quantity,
        'soldBy': userId,
      });
    });
  }
}