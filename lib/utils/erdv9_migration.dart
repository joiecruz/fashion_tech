import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ERDv9 Data Migration Helper
/// 
/// This script helps migrate existing data from ERDv8 to ERDv9 structure.
/// Run this once after deploying ERDv9 models to convert existing data.
/// 
/// IMPORTANT: Backup your database before running this migration!
class ERDv9Migration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main migration method - call this to migrate all data
  static Future<void> migrateToERDv9() async {
    try {
      debugPrint('Starting ERDv9 migration...');

      // Step 1: Create default color records from existing fabric colors
      await _migrateColorsFromFabrics();
      
      // Step 2: Create default category records
      await _migrateCategories();
      
      // Step 3: Create customer records from existing job orders
      await _migrateCustomersFromJobOrders();
      
      // Step 4: Update fabric documents to use colorID and categoryID
      await _migrateFabricReferences();
      
      // Step 5: Update product documents to use categoryID
      await _migrateProductReferences();
      
      // Step 6: Update product variant documents to use colorID
      await _migrateProductVariantReferences();
      
      // Step 7: Update job order documents with customerID and name
      await _migrateJobOrderReferences();

      debugPrint('ERDv9 migration completed successfully!');
    } catch (e) {
      debugPrint('ERDv9 migration failed: $e');
      rethrow;
    }
  }

  /// Create Color records from existing fabric color strings
  static Future<void> _migrateColorsFromFabrics() async {
    debugPrint('Migrating colors from fabrics...');
    
    final fabricsSnapshot = await _firestore.collection('fabrics').get();
    final Set<String> uniqueColors = {};
    
    // Collect unique color strings
    for (final doc in fabricsSnapshot.docs) {
      final data = doc.data();
      final color = data['color'] as String?;
      if (color != null && color.isNotEmpty) {
        uniqueColors.add(color);
      }
    }
    
    // Create Color documents
    final batch = _firestore.batch();
    for (final colorName in uniqueColors) {
      final colorRef = _firestore.collection('colors').doc();
      batch.set(colorRef, {
        'name': colorName,
        'hexCode': _generateHexFromColorName(colorName),
        'createdBy': 'system_migration',
      });
    }
    
    await batch.commit();
    debugPrint('Created ${uniqueColors.length} color records');
  }

  /// Create default Category records
  static Future<void> _migrateCategories() async {
    debugPrint('Creating default categories...');
    
    final batch = _firestore.batch();
    
    // Create default categories for each type
    final defaultCategories = [
      {'name': 'General', 'type': 'product'},
      {'name': 'Cotton', 'type': 'fabric'},
      {'name': 'Silk', 'type': 'fabric'},
      {'name': 'Material', 'type': 'expense'},
      {'name': 'Labor', 'type': 'expense'},
      {'name': 'Miscellaneous', 'type': 'expense'},
    ];
    
    for (final category in defaultCategories) {
      final categoryRef = _firestore.collection('categories').doc();
      batch.set(categoryRef, {
        ...category,
        'createdBy': 'system_migration',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Created ${defaultCategories.length} default categories');
  }

  /// Create Customer records from existing JobOrder customerName fields
  static Future<void> _migrateCustomersFromJobOrders() async {
    debugPrint('Migrating customers from job orders...');
    
    final jobOrdersSnapshot = await _firestore.collection('jobOrders').get();
    final Map<String, String> uniqueCustomers = {}; // name -> ID
    
    // Collect unique customer names
    for (final doc in jobOrdersSnapshot.docs) {
      final data = doc.data();
      final customerName = data['customerName'] as String?;
      if (customerName != null && customerName.isNotEmpty && !uniqueCustomers.containsKey(customerName)) {
        final customerRef = _firestore.collection('customers').doc();
        uniqueCustomers[customerName] = customerRef.id;
      }
    }
    
    // Create Customer documents
    final batch = _firestore.batch();
    for (final entry in uniqueCustomers.entries) {
      final customerRef = _firestore.collection('customers').doc(entry.value);
      batch.set(customerRef, {
        'fullName': entry.key,
        'contactNum': 'TBD', // To be updated manually
        'address': null,
        'email': null,
        'notes': 'Migrated from job order data',
        'createdBy': 'system_migration',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Created ${uniqueCustomers.length} customer records');
  }

  /// Update Fabric documents to use colorID and categoryID references
  static Future<void> _migrateFabricReferences() async {
    debugPrint('Updating fabric references...');
    
    // Get color mappings
    final colorsSnapshot = await _firestore.collection('colors').get();
    final Map<String, String> colorNameToId = {};
    for (final doc in colorsSnapshot.docs) {
      final data = doc.data();
      colorNameToId[data['name']] = doc.id;
    }
    
    // Get default category for fabrics
    final categoriesSnapshot = await _firestore.collection('categories')
        .where('type', isEqualTo: 'fabric')
        .limit(1)
        .get();
    final defaultCategoryId = categoriesSnapshot.docs.isNotEmpty 
        ? categoriesSnapshot.docs.first.id 
        : '';
    
    // Update fabric documents
    final fabricsSnapshot = await _firestore.collection('fabrics').get();
    final batch = _firestore.batch();
    
    for (final doc in fabricsSnapshot.docs) {
      final data = doc.data();
      final colorName = data['color'] as String?;
      final colorId = colorName != null ? colorNameToId[colorName] ?? '' : '';
      
      batch.update(doc.reference, {
        'colorID': colorId,
        'categoryID': defaultCategoryId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Updated ${fabricsSnapshot.docs.length} fabric records');
  }

  /// Update Product documents to use categoryID references
  static Future<void> _migrateProductReferences() async {
    debugPrint('Updating product references...');
    
    // Get default category for products
    final categoriesSnapshot = await _firestore.collection('categories')
        .where('type', isEqualTo: 'product')
        .limit(1)
        .get();
    final defaultCategoryId = categoriesSnapshot.docs.isNotEmpty 
        ? categoriesSnapshot.docs.first.id 
        : '';
    
    // Update product documents
    final productsSnapshot = await _firestore.collection('products').get();
    final batch = _firestore.batch();
    
    for (final doc in productsSnapshot.docs) {
      batch.update(doc.reference, {
        'categoryID': defaultCategoryId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Updated ${productsSnapshot.docs.length} product records');
  }

  /// Update ProductVariant documents to use colorID references
  static Future<void> _migrateProductVariantReferences() async {
    debugPrint('Updating product variant references...');
    
    // Get color mappings
    final colorsSnapshot = await _firestore.collection('colors').get();
    final Map<String, String> colorNameToId = {};
    for (final doc in colorsSnapshot.docs) {
      final data = doc.data();
      colorNameToId[data['name']] = doc.id;
    }
    
    // Update product variant documents
    final variantsSnapshot = await _firestore.collection('productVariants').get();
    final batch = _firestore.batch();
    
    for (final doc in variantsSnapshot.docs) {
      final data = doc.data();
      final colorName = data['color'] as String?;
      final colorId = colorName != null ? colorNameToId[colorName] ?? '' : '';
      
      batch.update(doc.reference, {
        'colorID': colorId,
      });
    }
    
    await batch.commit();
    debugPrint('Updated ${variantsSnapshot.docs.length} product variant records');
  }

  /// Update JobOrder documents with customerID and name fields
  static Future<void> _migrateJobOrderReferences() async {
    debugPrint('Updating job order references...');
    
    // Get customer mappings
    final customersSnapshot = await _firestore.collection('customers').get();
    final Map<String, String> customerNameToId = {};
    for (final doc in customersSnapshot.docs) {
      final data = doc.data();
      customerNameToId[data['fullName']] = doc.id;
    }
    
    // Update job order documents
    final jobOrdersSnapshot = await _firestore.collection('jobOrders').get();
    final batch = _firestore.batch();
    
    for (final doc in jobOrdersSnapshot.docs) {
      final data = doc.data();
      final customerName = data['customerName'] as String? ?? '';
      final customerId = customerNameToId[customerName] ?? '';
      final name = data['name'] as String? ?? 'Job Order ${doc.id}';
      
      batch.update(doc.reference, {
        'customerID': customerId,
        'name': name,
        'linkedProductID': null, // Set to null initially
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Updated ${jobOrdersSnapshot.docs.length} job order records');
  }

  /// Generate a hex color from color name (simple mapping)
  static String? _generateHexFromColorName(String colorName) {
    final colorMap = {
      'red': '#FF0000',
      'blue': '#0000FF',
      'green': '#00FF00',
      'yellow': '#FFFF00',
      'black': '#000000',
      'white': '#FFFFFF',
      'purple': '#800080',
      'orange': '#FFA500',
      'pink': '#FFC0CB',
      'brown': '#A52A2A',
      'gray': '#808080',
      'grey': '#808080',
    };
    
    return colorMap[colorName.toLowerCase()];
  }
}
