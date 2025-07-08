import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/category_service.dart';
import 'lib/backend/firebase_options.dart';

/// Test app to verify category system is working
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CategoryTestApp());
}

class CategoryTestApp extends StatelessWidget {
  const CategoryTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Test',
      home: const CategoryTestPage(),
    );
  }
}

class CategoryTestPage extends StatefulWidget {
  const CategoryTestPage({super.key});

  @override
  State<CategoryTestPage> createState() => _CategoryTestPageState();
}

class _CategoryTestPageState extends State<CategoryTestPage> {
  bool _isLoading = false;
  String _status = 'Ready to test categories';
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _testCategories();
  }

  Future<void> _testCategories() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing category system...';
    });

    try {
      // 1. Check if categories exist
      final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
      print('Categories initialized: $isInitialized');
      
      // 2. Initialize if needed
      if (!isInitialized) {
        await CategoryService.initializeDefaultCategories();
        print('Categories initialized successfully');
      }
      
      // 3. Fetch all categories
      final categories = await CategoryService.getAllProductCategories();
      print('Found ${categories.length} categories');
      
      // 4. Test getting a specific category
      final topCategory = await CategoryService.getCategoryByName('top');
      print('Top category: $topCategory');
      
      setState(() {
        _categories = categories;
        _status = 'Category system working! Found ${categories.length} categories.';
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
        title: const Text('Category System Test'),
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
                      'Category System Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                    else
                      Text(_status),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testCategories,
                      child: const Text('Re-test Categories'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_categories.isNotEmpty) ...[
              const Text(
                'Available Categories:',
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category['description'] ?? ''),
                            Text(
                              'ID: ${category['name']} • Type: ${category['type']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (category['isDefault'] == true)
                              const Chip(
                                label: Text('Default'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            const SizedBox(height: 2),
                            if (category['isActive'] == true)
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          ],
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
      case 'accessories':
        return Icons.watch;
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
      case 'accessories':
        return Colors.orange;
      case 'uncategorized':
      default:
        return Colors.grey;
    }
  }
}
