import 'package:cloud_firestore/cloud_firestore.dart';

class FetchProductsBackend {
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    print('DEBUG: fetchProducts called');
    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('deletedAt', isNull: true)
          .orderBy('updatedAt', descending: true)
          .get();

      print('DEBUG: productsSnapshot.docs.length = ${productsSnapshot.docs.length}');

      List<Map<String, dynamic>> products = [];

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        print('DEBUG: Product found: ${productData['name']} (${productDoc.id})');

        // Fetch variants for this product
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('productVariants')
            .where('productID', isEqualTo: productDoc.id)
            .get();

        int totalStock = 0;
        List<Map<String, dynamic>> variants = [];

        for (var variantDoc in variantsSnapshot.docs) {
          final variantData = variantDoc.data();
          totalStock += (variantData['quantityInStock'] ?? 0) as int;
          variants.add({
            'variantID': variantDoc.id,
            'size': variantData['size'] ?? '',
            'color': variantData['color'] ?? '',
            'quantityInStock': variantData['quantityInStock'] ?? 0,
            'unitCostEstimate': (variantData['unitCostEstimate'] ?? 0.0).toDouble(),
          });
        }

        // Fetch primary product image
        String imageUrl = '';
        try {
          final imageSnapshot = await FirebaseFirestore.instance
              .collection('productImages')
              .where('productID', isEqualTo: productDoc.id)
              .where('isPrimary', isEqualTo: true)
              .limit(1)
              .get();

          if (imageSnapshot.docs.isNotEmpty) {
            imageUrl = imageSnapshot.docs.first.data()['imageURL'] ?? '';
            print('DEBUG: Image found for ${productData['name']}: $imageUrl');
          }
        } catch (e) {
          print('DEBUG: Error fetching image for ${productData['name']}: $e');
          imageUrl = '';
        }

        double price = (productData['price'] ?? 0.0).toDouble();
        double potentialValue = price * totalStock;
        bool lowStock = totalStock < 5;

        products.add({
          'productID': productDoc.id,
          'name': productData['name'] ?? 'Unknown Product',
          'description': productData['description'],
          'notes': productData['notes'],
          'category': productData['category'] ?? 'Uncategorized',
          'price': price,
          'unitCostEstimate': (productData['unitCostEstimate'] ?? 0.0).toDouble(),
          'isUpcycled': productData['isUpcycled'] ?? false,
          'isMade': productData['isMade'] ?? false,
          'stock': totalStock,
          'lowStock': lowStock,
          'potentialValue': potentialValue,
          'imageUrl': imageUrl,
          'variants': variants,
          'createdAt': productData['createdAt'],
          'updatedAt': productData['updatedAt'],
        });
      }

      print('DEBUG: Returning ${products.length} products');
      return products;
    } catch (e) {
      print('ERROR in fetchProducts: $e');
      rethrow;
    }
  }
}