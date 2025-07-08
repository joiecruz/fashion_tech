import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/category_service.dart';

/// Simple script to initialize default categories in the database
class CategoryInitializer {
  
  /// Initialize Firebase and default categories
  static Future<void> initializeCategories() async {
    try {
      // Ensure Firebase is initialized
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      
      print('🔄 Initializing default product categories...');
      
      // Check if categories exist
      final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
      
      if (isInitialized) {
        print('✅ Default categories already exist in the database');
        
        // Show existing categories
        final categories = await CategoryService.getAllProductCategories();
        print('📋 Found ${categories.length} categories:');
        for (final category in categories) {
          print('   - ${category['displayName']} (${category['name']})');
        }
      } else {
        print('🚀 Creating default categories...');
        await CategoryService.initializeDefaultCategories();
        
        // Verify creation
        final categories = await CategoryService.getAllProductCategories();
        print('✅ Successfully created ${categories.length} default categories:');
        for (final category in categories) {
          print('   - ${category['displayName']} (${category['name']}) - ${category['description']}');
        }
      }
      
      print('🎉 Category initialization complete!');
      
    } catch (e) {
      print('❌ Error initializing categories: $e');
      rethrow;
    }
  }
}

/// Widget that can be used to trigger category initialization
class CategoryInitializerWidget extends StatefulWidget {
  const CategoryInitializerWidget({super.key});

  @override
  State<CategoryInitializerWidget> createState() => _CategoryInitializerWidgetState();
}

class _CategoryInitializerWidgetState extends State<CategoryInitializerWidget> {
  bool _isLoading = false;
  String _status = 'Ready to initialize categories';
  List<Map<String, dynamic>> _categories = [];

  Future<void> _initializeCategories() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing categories...';
    });

    try {
      await CategoryInitializer.initializeCategories();
      final categories = await CategoryService.getAllProductCategories();
      
      setState(() {
        _categories = categories;
        _status = 'Categories initialized successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Initializer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category Database Setup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _initializeCategories,
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Initializing...'),
                                ],
                              )
                            : const Text('Initialize Categories'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_categories.isNotEmpty) ...[
              const Text(
                'Initialized Categories:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          _getCategoryIcon(category['name']),
                          color: _getCategoryColor(category['name']),
                        ),
                        title: Text(category['displayName'] ?? category['name']),
                        subtitle: Text(category['description'] ?? ''),
                        trailing: Chip(
                          label: Text(category['name']),
                          backgroundColor: Colors.blue[100],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'top':
        return Icons.checkroom;
      case 'bottom':
        return Icons.person;
      case 'outerwear':
        return Icons.ac_unit;
      case 'dress':
        return Icons.woman;
      case 'jumpsuit':
        return Icons.fitness_center;
      case 'activewear':
        return Icons.sports;
      case 'underwear':
        return Icons.favorite;
      case 'sleepwear':
        return Icons.bedtime;
      case 'swimwear':
        return Icons.pool;
      case 'footwear':
        return Icons.directions_walk;
      case 'accessories':
        return Icons.watch;
      case 'formal':
        return Icons.star;
      case 'vintage':
        return Icons.history;
      case 'maternity':
        return Icons.pregnant_woman;
      case 'uncategorized':
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'top':
        return Colors.blue;
      case 'bottom':
        return Colors.green;
      case 'outerwear':
        return Colors.purple;
      case 'dress':
        return Colors.pink;
      case 'jumpsuit':
        return Colors.teal;
      case 'activewear':
        return Colors.red;
      case 'underwear':
        return Colors.deepPurple;
      case 'sleepwear':
        return Colors.indigo;
      case 'swimwear':
        return Colors.cyan;
      case 'footwear':
        return Colors.brown;
      case 'accessories':
        return Colors.orange;
      case 'formal':
        return Colors.amber;
      case 'vintage':
        return Colors.deepOrange;
      case 'maternity':
        return Colors.lightGreen;
      case 'uncategorized':
      default:
        return Colors.grey;
    }
  }
}
