// Simple verification of categories in database
// Add this to any existing dart file and run it

void checkCategoriesInDatabase() async {
  print('🔍 CHECKING CATEGORIES IN DATABASE...');
  
  try {
    // Import your service
    // import '../lib/services/category_service.dart';
    
    // Check if categories exist
    final exist = await CategoryService.areDefaultCategoriesInitialized();
    print('Categories exist in database: $exist');
    
    if (!exist) {
      print('📥 Adding categories to database...');
      await CategoryService.initializeDefaultCategories();
      print('✅ Categories added successfully!');
    }
    
    // Get all categories
    final categories = await CategoryService.getAllProductCategories();
    print('📊 Found ${categories.length} categories in database:');
    
    for (var cat in categories) {
      print('  • ${cat['displayName']} (${cat['name']})');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
