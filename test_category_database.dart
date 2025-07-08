import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/category_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CategoryTestApp());
}

class CategoryTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Database Test',
      home: CategoryTestScreen(),
    );
  }
}

class CategoryTestScreen extends StatefulWidget {
  @override
  _CategoryTestScreenState createState() => _CategoryTestScreenState();
}

class _CategoryTestScreenState extends State<CategoryTestScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String _status = 'Checking database...';

  @override
  void initState() {
    super.initState();
    _checkAndInitializeCategories();
  }

  Future<void> _checkAndInitializeCategories() async {
    try {
      setState(() {
        _status = 'Checking if categories exist in database...';
        _loading = true;
      });

      // Check if categories exist
      bool categoriesExist = await CategoryService.areDefaultCategoriesInitialized();
      
      if (!categoriesExist) {
        setState(() {
          _status = 'No categories found. Initializing default categories...';
        });
        
        // Initialize categories
        await CategoryService.initializeDefaultCategories();
        
        setState(() {
          _status = 'Categories initialized! Loading categories...';
        });
      } else {
        setState(() {
          _status = 'Categories found in database. Loading...';
        });
      }

      // Load categories
      final categories = await CategoryService.getAllProductCategories();
      
      setState(() {
        _categories = categories;
        _loading = false;
        _status = 'Loaded ${categories.length} categories from database';
      });

    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _loading = true;
      _status = 'Refreshing categories...';
    });

    try {
      final categories = await CategoryService.refreshCategories();
      setState(() {
        _categories = categories;
        _loading = false;
        _status = 'Refreshed ${categories.length} categories';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error refreshing: $e';
      });
    }
  }

  Future<void> _checkFirestoreDirectly() async {
    setState(() {
      _loading = true;
      _status = 'Checking Firestore collection directly...';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .get();
      
      setState(() {
        _loading = false;
        _status = 'Direct Firestore check: Found ${snapshot.docs.length} documents in categories collection';
      });

      // Print details of each document
      for (var doc in snapshot.docs) {
        print('Category: ${doc.data()}');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error checking Firestore: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Category Database Test'),
        backgroundColor: Colors.blue,
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
                    Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(_status),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _loading ? null : _refreshCategories,
                          child: Text('Refresh Categories'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _checkFirestoreDirectly,
                          child: Text('Check Firestore Direct'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Categories in Database:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _categories.isEmpty
                      ? Center(
                          child: Text(
                            'No categories found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.category,
                                  color: Colors.blue,
                                ),
                                title: Text(category['displayName'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${category['name']}'),
                                    if (category['description'] != null)
                                      Text(
                                        category['description'],
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    Text(
                                      'Created by: ${category['createdBy'] ?? "Unknown"}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
