import 'package:flutter/material.dart';
import 'lib/frontend/common/simple_category_dropdown.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestDropdownPage(),
    );
  }
}

class TestDropdownPage extends StatefulWidget {
  @override
  _TestDropdownPageState createState() => _TestDropdownPageState();
}

class _TestDropdownPageState extends State<TestDropdownPage> {
  String _selectedCategory = 'uncategorized';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Category Dropdown Test')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Selected Category: $_selectedCategory'),
            SizedBox(height: 20),
            SimpleCategoryDropdown(
              selectedCategory: _selectedCategory,
              onChanged: (value) {
                print('Dropdown changed to: $value');
                setState(() {
                  _selectedCategory = value ?? 'uncategorized';
                });
              },
              isRequired: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Current selected category: $_selectedCategory');
              },
              child: Text('Print Selected Category'),
            ),
          ],
        ),
      ),
    );
  }
}
