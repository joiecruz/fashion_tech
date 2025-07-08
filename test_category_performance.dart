import 'package:flutter/material.dart';
import 'lib/frontend/common/simple_category_dropdown.dart';

void main() {
  runApp(CategoryPerformanceTest());
}

class CategoryPerformanceTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Dropdown Performance Test',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Category Dropdown Test'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                'Testing Category Dropdown Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              SimpleCategoryDropdown(
                selectedCategory: 'uncategorized',
                onChanged: (value) {
                  print('Selected category: $value');
                },
                isRequired: true,
              ),
              SizedBox(height: 20),
              Text(
                'This dropdown should load instantly with fallback categories and update from Firestore in the background.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
