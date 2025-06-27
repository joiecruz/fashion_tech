class ProductVariant {
  final String id;
  final String productID;
  String size;
  String color;
  int quantityInStock;
  double? unitCostEstimate;

  int get quantity => quantityInStock;
  set quantity(int value) => quantityInStock = value;

  ProductVariant({
    required this.id,
    required this.productID,
    required this.size,
    required this.color,
    required this.quantityInStock,
    this.unitCostEstimate,
  });

  factory ProductVariant.fromMap(String id, Map<String, dynamic> data) {
    return ProductVariant(
      id: id,
      productID: data['productID'] ?? '',
      size: data['size'] ?? '',
      color: data['color'] ?? '',
      quantityInStock: data['quantityInStock'] ?? 0,
      unitCostEstimate: data['unitCostEstimate']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'size': size,
      'color': color,
      'quantityInStock': quantityInStock,
      'unitCostEstimate': unitCostEstimate,
    };
  }
}
