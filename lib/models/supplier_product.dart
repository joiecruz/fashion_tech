class SupplierProduct {
  final String id;
  final String supplierID;
  final String productID;
  final double supplyPrice;
  final int? minOrderQty;
  final int? leadTimeDays;

  SupplierProduct({
    required this.id,
    required this.supplierID,
    required this.productID,
    required this.supplyPrice,
    this.minOrderQty,
    this.leadTimeDays,
  });

  factory SupplierProduct.fromMap(String id, Map<String, dynamic> data) {
    return SupplierProduct(
      id: id,
      supplierID: data['supplierID'] ?? '',
      productID: data['productID'] ?? '',
      supplyPrice: (data['supplyPrice'] ?? 0).toDouble(),
      minOrderQty: data['minOrderQty'],
      leadTimeDays: data['leadTimeDays'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierID': supplierID,
      'productID': productID,
      'supplyPrice': supplyPrice,
      'minOrderQty': minOrderQty,
      'leadTimeDays': leadTimeDays,
    };
  }
}
