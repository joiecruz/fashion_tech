import 'package:cloud_firestore/cloud_firestore.dart';

class ProductImage {
  final String id;
  final String productID;
  final String imageURL;
  final bool? isPrimary;
  final String uploadedBy;
  final DateTime uploadedAt;

  ProductImage({
    required this.id,
    required this.productID,
    required this.imageURL,
    this.isPrimary,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  factory ProductImage.fromMap(String id, Map<String, dynamic> data) {
    return ProductImage(
      id: id,
      productID: data['productID'] ?? '',
      imageURL: data['imageURL'] ?? '',
      isPrimary: data['isPrimary'],
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: (data['uploadedAt'] is Timestamp)
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['uploadedAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'imageURL': imageURL,
      'isPrimary': isPrimary,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt), // Convert DateTime to Firestore Timestamp
    };
  }
}
