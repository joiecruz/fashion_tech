class Product {
  final String id; // Maps to productID in ERDv7
  final String name;
  final String? description; // For additional product details, notes, supplier info
  final String? notes; // ERDv7 field for product-specific notes
  final double price;
  final double? unitCostEstimate;
  final String category;
  final bool isUpcycled;
  final bool isMade;
  final String createdBy; // User ID of who created this product
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // New field for soft delete in ERDv7

  Product({
    required this.id,
    required this.name,
    this.description,
    this.notes,
    required this.price,
    this.unitCostEstimate,
    required this.category,
    required this.isUpcycled,
    required this.isMade,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'],
      notes: data['notes'],
      price: (data['price'] ?? 0).toDouble(),
      unitCostEstimate: data['unitCostEstimate']?.toDouble(),
      category: data['category'] ?? '',
      isUpcycled: data['isUpcycled'] ?? false,
      isMade: data['isMade'] ?? false,
      createdBy: data['createdBy'] ?? 'anonymous',
      createdAt: data['createdAt'] is DateTime ? data['createdAt'] : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: data['updatedAt'] is DateTime ? data['updatedAt'] : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
      deletedAt: data['deletedAt'] != null 
          ? (data['deletedAt'] is DateTime ? data['deletedAt'] : DateTime.tryParse(data['deletedAt'].toString())) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'notes': notes,
      'price': price,
      'unitCostEstimate': unitCostEstimate,
      'category': category,
      'isUpcycled': isUpcycled,
      'isMade': isMade,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}
