class Product {
  final String id; // Maps to productID in ERDv9
  final String name;
  final String? notes; // ERDv9 field for product-specific notes
  final double price;
  final String categoryID; // Changed from category to categoryID in ERDv9
  final bool isUpcycled;
  final bool isMade;
  final String createdBy; // User ID of who created this product
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // New field for soft delete in ERDv9
  final DateTime? acquisitionDate; // Date the product was acquired
  final String? imageURL; // Primary image URL
  final int stock; // Total stock quantity
  final List<String> variantIDs; // List of variant IDs linked to this product

  Product({
    required this.id,
    required this.name,
    this.notes,
    required this.price,
    required this.categoryID,
    required this.isUpcycled,
    required this.isMade,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.acquisitionDate,
    this.imageURL,
    this.stock = 0,
    this.variantIDs = const [],
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      notes: data['notes'],
      price: (data['price'] ?? 0).toDouble(),
      categoryID: data['categoryID'] ?? data['category'] ?? '', // Handle legacy data
      isUpcycled: data['isUpcycled'] ?? false,
      isMade: data['isMade'] ?? false,
      createdBy: data['createdBy'] ?? 'anonymous',
      createdAt: data['createdAt'] is DateTime ? data['createdAt'] : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: data['updatedAt'] is DateTime ? data['updatedAt'] : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
      deletedAt: data['deletedAt'] != null 
          ? (data['deletedAt'] is DateTime ? data['deletedAt'] : DateTime.tryParse(data['deletedAt'].toString())) 
          : null,
      acquisitionDate: data['acquisitionDate'] != null 
          ? (data['acquisitionDate'] is DateTime ? data['acquisitionDate'] : DateTime.tryParse(data['acquisitionDate'].toString())) 
          : null,
      imageURL: data['imageURL'],
      stock: data['stock']?.toInt() ?? 0,
      variantIDs: data['variantIDs'] != null ? List<String>.from(data['variantIDs']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'notes': notes,
      'price': price,
      'categoryID': categoryID,
      'isUpcycled': isUpcycled,
      'isMade': isMade,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'acquisitionDate': acquisitionDate?.toIso8601String(),
      'imageURL': imageURL,
      'stock': stock,
      'variantIDs': variantIDs,
    };
  }
}
