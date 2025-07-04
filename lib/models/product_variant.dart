class ProductVariant {
  final String id;
  final String productID;
  String size;
  String colorID; // Changed from color to colorID in ERDv9
  int quantityInStock;

  int get quantity => quantityInStock;
  set quantity(int value) => quantityInStock = value;

  ProductVariant({
    required this.id,
    required this.productID,
    required this.size,
    required this.colorID,
    required this.quantityInStock,
  });

  factory ProductVariant.fromMap(String id, Map<String, dynamic> data) {
    return ProductVariant(
      id: id,
      productID: data['productID'] ?? '',
      size: data['size'] ?? '',
      colorID: data['colorID'] ?? data['color'] ?? '', // Handle legacy data
      quantityInStock: data['quantityInStock'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'size': size,
      'colorID': colorID,
      'quantityInStock': quantityInStock,
    };
  }
}
