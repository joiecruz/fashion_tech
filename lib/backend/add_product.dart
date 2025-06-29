import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/product_image.dart';

class AddProductBackend {
  static Future<String> addProduct(Product product) async {
    final productRef = FirebaseFirestore.instance.collection('products').doc(product.id);
    await productRef.set(product.toMap());
    return productRef.id;
  }

  static Future<void> addProductVariant({
    required String productID,
    required String size,
    required String color,
    required int quantityInStock,
  }) async {
    await FirebaseFirestore.instance.collection('productVariants').add({
      'productID': productID,
      'size': size,
      'color': color,
      'quantityInStock': quantityInStock,
    });
  }

  static Future<void> addProductImage(ProductImage image) async {
    final productImageRef = FirebaseFirestore.instance.collection('productImages').doc(image.id);
    await productImageRef.set(image.toMap());
  }
}