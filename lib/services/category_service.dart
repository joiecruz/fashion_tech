import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing product categories in the database
class CategoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _categoriesCollection = 'categories';
  
  // Cache for categories to avoid repeated Firestore queries
  static List<Map<String, dynamic>>? _cachedCategories;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Default product categories to populate in the database
  static final List<Map<String, dynamic>> _defaultCategories = [
    {
      'name': 'top',
      'displayName': 'Top',
      'description': 'Shirts, blouses, t-shirts, sweaters, tank tops, etc.',
      'type': 'product',
    },
    {
      'name': 'bottom',
      'displayName': 'Bottom',
      'description': 'Pants, jeans, shorts, skirts, leggings, etc.',
      'type': 'product',
    },
    {
      'name': 'outerwear',
      'displayName': 'Outerwear',
      'description': 'Jackets, coats, blazers, hoodies, cardigans, etc.',
      'type': 'product',
    },
    {
      'name': 'dress',
      'displayName': 'Dress',
      'description': 'Dresses, gowns, sundresses, cocktail dresses, etc.',
      'type': 'product',
    },
    {
      'name': 'activewear',
      'displayName': 'Activewear',
      'description': 'Sportswear, gym clothes, yoga wear, athletic gear, etc.',
      'type': 'product',
    },
    {
      'name': 'underwear',
      'displayName': 'Underwear & Intimates',
      'description': 'Bras, underwear, lingerie, shapewear, etc.',
      'type': 'product',
    },
    {
      'name': 'sleepwear',
      'displayName': 'Sleepwear',
      'description': 'Pajamas, nightgowns, robes, loungewear, etc.',
      'type': 'product',
    },
    {
      'name': 'swimwear',
      'displayName': 'Swimwear',
      'description': 'Bikinis, one-pieces, swim shorts, cover-ups, etc.',
      'type': 'product',
    },
    {
      'name': 'footwear',
      'displayName': 'Footwear',
      'description': 'Shoes, boots, sandals, heels, sneakers, etc.',
      'type': 'product',
    },
    {
      'name': 'accessories',
      'displayName': 'Accessories',
      'description': 'Bags, belts, jewelry, scarves, hats, etc.',
      'type': 'product',
    },
    {
      'name': 'formal',
      'displayName': 'Formal Wear',
      'description': 'Evening gowns, tuxedos, formal suits, etc.',
      'type': 'product',
    },
    {
      'name': 'uncategorized',
      'displayName': 'Uncategorized',
      'description': 'Items that don\'t fit into other categories',
      'type': 'product',
    },
  ];

  /// Check if default categories have been initialized
  static Future<bool> areDefaultCategoriesInitialized() async {
    try {
      final snapshot = await _firestore
          .collection(_categoriesCollection)
          .where('type', isEqualTo: 'product')
          .where('createdBy', isEqualTo: 'SYSTEM_DEFAULT')
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Initialize default categories in the database
  static Future<void> initializeDefaultCategories() async {
    try {
      // Check if categories already exist
      final existingCheck = await areDefaultCategoriesInitialized();
      if (existingCheck) {
        return;
      }

      // Add each category to the database
      final batch = _firestore.batch();
      
      for (final categoryData in _defaultCategories) {
        final docRef = _firestore.collection(_categoriesCollection).doc();
        final dataToAdd = {
          'name': categoryData['name'],
          'displayName': categoryData['displayName'],
          'description': categoryData['description'],
          'type': categoryData['type'],
          'createdBy': 'SYSTEM_DEFAULT',
        };
        batch.set(docRef, dataToAdd);
      }

      await batch.commit();
      
      // Clear cache after adding new categories
      clearCache();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all product categories from the database
  static Future<List<Map<String, dynamic>>> getAllProductCategories() async {
    try {
      // Check cache first
      if (_cachedCategories != null && 
          _cacheTimestamp != null && 
          DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry) {
        return _cachedCategories!;
      }

      final snapshot = await _firestore
          .collection(_categoriesCollection)
          .where('type', isEqualTo: 'product')
          .get(); // Removed orderBy to avoid index requirements
      
      final categories = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      
      // Sort manually in memory
      categories.sort((a, b) => (a['displayName'] ?? '').compareTo(b['displayName'] ?? ''));
      
      // Update cache
      _cachedCategories = categories;
      _cacheTimestamp = DateTime.now();
      
      return categories;
    } catch (e) {
      // Return cached data if available, even if expired
      if (_cachedCategories != null) {
        return _cachedCategories!;
      }
      return [];
    }
  }

  /// Get a category by name
  static Future<Map<String, dynamic>?> getCategoryByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection(_categoriesCollection)
          .where('name', isEqualTo: name)
          .where('type', isEqualTo: 'product')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Add a new product category
  static Future<String?> addCategory({
    required String name,
    required String displayName,
    String? description,
  }) async {
    try {
      final docRef = await _firestore.collection(_categoriesCollection).add({
        'name': name.toLowerCase(),
        'displayName': displayName,
        'description': description ?? '',
        'type': 'product',
        'createdBy': 'USER', // Mark as user-created
      });
      
      print('Successfully added category: $displayName');
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Clear the category cache (call when categories are modified)
  static void clearCache() {
    _cachedCategories = null;
    _cacheTimestamp = null;
  }

  /// Force refresh categories from database
  static Future<List<Map<String, dynamic>>> refreshCategories() async {
    clearCache();
    return getAllProductCategories();
  }
}
