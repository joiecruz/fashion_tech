class Product {
  final String id;
  final String name;
  final double price;
  final double? unitCostEstimate;
  final String category;
  final bool isUpcycled;
  final bool isMade;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.unitCostEstimate,
    required this.category,
    required this.isUpcycled,
    required this.isMade,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      unitCostEstimate: data['unitCostEstimate']?.toDouble(),
      category: data['category'] ?? '',
      isUpcycled: data['isUpcycled'] ?? false,
      isMade: data['isMade'] ?? false,
      createdAt: data['createdAt'] is DateTime ? data['createdAt'] : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: data['updatedAt'] is DateTime ? data['updatedAt'] : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'unitCostEstimate': unitCostEstimate,
      'category': category,
      'isUpcycled': isUpcycled,
      'isMade': isMade,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
