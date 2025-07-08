import 'package:flutter/material.dart';
import 'lib/frontend/common/simple_category_dropdown.dart';

void main() {
  runApp(CategoryDropdownTest());
}

class CategoryDropdownTest extends StatefulWidget {
  @override
  _CategoryDropdownTestState createState() => _CategoryDropdownTestState();
}

class _CategoryDropdownTestState extends State<CategoryDropdownTest> {
  String? _selectedCategory = 'uncategorized';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Dropdown Test',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Category Dropdown Test'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Category Dropdown Implementation:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Category:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      SimpleCategoryDropdown(
                        selectedCategory: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                          print('Category selected: $value');
                        },
                        isRequired: true,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Category:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _selectedCategory ?? 'None',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected Categories:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This dropdown should show:\n'
                        '• Top\n'
                        '• Bottom\n' 
                        '• Outerwear\n'
                        '• Dress\n'
                        '• Activewear\n'
                        '• Underwear & Intimates\n'
                        '• Sleepwear\n'
                        '• Swimwear\n'
                        '• Footwear\n'
                        '• Accessories\n'
                        '• Formal Wear\n'
                        '• Uncategorized',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
