import 'package:flutter/material.dart';
import 'lib/frontend/common/simple_category_dropdown.dart';

/// Test to verify that SimpleCategoryDropdown properly shows the selected category
/// when initialized with a value from the database.

void main() {
  runApp(TestDropdownApp());
}

class TestDropdownApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Dropdown Test',
      home: TestDropdownPage(),
    );
  }
}

class TestDropdownPage extends StatefulWidget {
  @override
  State<TestDropdownPage> createState() => _TestDropdownPageState();
}

class _TestDropdownPageState extends State<TestDropdownPage> {
  String? _selectedCategory = 'top'; // Simulate loading from database
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate database loading delay
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _selectedCategory = 'dress'; // Simulate loaded category from database
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Category Dropdown Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Scenario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This test simulates the edit modal scenario:\n'
                      '1. Initially shows loading state\n'
                      '2. After 2 seconds, loads category "dress" from database\n'
                      '3. Dropdown should show "Dress" as selected',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Loading job order data...'),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Dropdown:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  SimpleCategoryDropdown(
                    selectedCategory: _selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    isRequired: false,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Current selection: $_selectedCategory',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            SizedBox(height: 20),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Expected Behavior',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Dropdown should show "Dress" as selected after loading\n'
                      '• Should NOT show "Select a category" if a valid category is loaded\n'
                      '• Should display the proper category icon and display name',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
