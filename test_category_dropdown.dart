import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/category_service.dart';
import 'lib/frontend/common/simple_category_dropdown.dart';
import 'lib/backend/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(CategoryTestApp());
}

class CategoryTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Test',
      home: CategoryTestPage(),
    );
  }
}

class CategoryTestPage extends StatefulWidget {
  @override
  _CategoryTestPageState createState() => _CategoryTestPageState();
}

class _CategoryTestPageState extends State<CategoryTestPage> {
  String? selectedCategory;
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoriesFromDatabase();
  }

  Future<void> _loadCategoriesFromDatabase() async {
    try {
      print('🔄 Testing category system...');
      
      // Initialize categories if needed
      final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
      print('Categories already initialized: $isInitialized');
      
      if (!isInitialized) {
        print('Initializing categories...');
        await CategoryService.initializeDefaultCategories();
      }
      
      // Load categories
      final loadedCategories = await CategoryService.getAllProductCategories();
      print('Loaded ${loadedCategories.length} categories from database:');
      
      for (final category in loadedCategories) {
        print('  - ${category['displayName']} (${category['name']})');
      }
      
      setState(() {
        categories = loadedCategories;
        isLoading = false;
      });
      
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Category System Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category System Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),
            
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else ...[
              Text(
                'Categories from Database (${categories.length} found):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 10),
              
              // Show loaded categories
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categories.map((category) => 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${category['displayName']} (${category['name']})'),
                    ),
                  ).toList(),
                ),
              ),
              
              SizedBox(height: 20),
              
              Text(
                'Category Dropdown Test:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 10),
              
              // Test the dropdown widget
              SimpleCategoryDropdown(
                selectedCategory: selectedCategory,
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                  print('Selected category: $value');
                },
              ),
              
              SizedBox(height: 20),
              
              if (selectedCategory != null)
                Text(
                  'Selected: $selectedCategory',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
