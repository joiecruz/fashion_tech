import 'package:cloud_firestore/cloud_firestore.dart';

class SalesLog {
  final String id;
  final String productID;
  final String variantID;
  final int qtySold;
  final double sellingPrice;
  final DateTime dateSold;

  SalesLog({
    required this.id,
    required this.productID,
    required this.variantID,
    required this.qtySold,
    required this.sellingPrice,
    required this.dateSold,
  });

  factory SalesLog.fromMap(String id, Map<String, dynamic> data) {
    return SalesLog(
      id: id,
      productID: data['productID'] ?? '',
      variantID: data['variantID'] ?? '',
      qtySold: data['qtySold'] ?? 0,
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      dateSold: (data['dateSold'] is Timestamp)
          ? (data['dateSold'] as Timestamp).toDate()
          : DateTime.tryParse(data['dateSold'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'variantID': variantID,
      'qtySold': qtySold,
      'sellingPrice': sellingPrice,
      'dateSold': dateSold,
    };
  }
}
