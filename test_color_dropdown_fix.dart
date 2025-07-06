// Test to verify the stack overflow fix in DatabaseColorDropdown
import 'package:flutter/material.dart';
import 'lib/frontend/common/database_color_dropdown.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Dropdown Stack Overflow Test',
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _selectedColor = 'Black';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Dropdown Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Testing DatabaseColorDropdown for Stack Overflow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Selected Color:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedColor,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Color Dropdown:'),
            const SizedBox(height: 8),
            DatabaseColorDropdown(
              selectedColor: _selectedColor,
              onChanged: (value) {
                if (value != null && value != _selectedColor) {
                  setState(() {
                    _selectedColor = value;
                  });
                }
              },
              isRequired: true,
              label: 'Select Color',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Current selected color: $_selectedColor');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected color: $_selectedColor'),
                  ),
                );
              },
              child: const Text('Test Selection'),
            ),
          ],
        ),
      ),
    );
  }
}
