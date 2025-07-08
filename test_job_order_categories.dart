import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/category_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(JobOrderCategoryTest());
}

class JobOrderCategoryTest extends StatefulWidget {
  @override
  _JobOrderCategoryTestState createState() => _JobOrderCategoryTestState();
}

class _JobOrderCategoryTestState extends State<JobOrderCategoryTest> {
  List<Map<String, dynamic>> _products = [];
  Map<String, String> _categoryNames = {};
  bool _loading = true;
  String _status = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _status = 'Loading categories...';
      });

      // Load categories
      final categories = await CategoryService.getAllProductCategories();
      _categoryNames = {
        for (var category in categories)
          category['name']: category['displayName'] ?? category['name']
      };

      setState(() {
        _status = 'Loading products...';
      });

      // Load products
      final productsSnap = await FirebaseFirestore.instance.collection('products').get();
      
      _products = productsSnap.docs.map((doc) {
        final data = doc.data();
        
        // Handle both new categoryID and legacy category fields
        final categoryID = data['categoryID'] ?? data['category'] ?? 'uncategorized';
        final categoryDisplayName = _categoryNames[categoryID] ?? categoryID.toString().toUpperCase();
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Product',
          'categoryID': categoryID,
          'categoryName': categoryDisplayName,
          'price': data['price'] ?? 0.0,
          'isUpcycled': data['isUpcycled'] ?? false,
        };
      }).toList();

      setState(() {
        _loading = false;
        _status = 'Loaded ${_products.length} products with ${_categoryNames.length} categories';
      });

    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Order Category Test',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Job Order Category Test'),
          backgroundColor: Colors.orange,
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
                      Text(
                        'Available Categories:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _categoryNames.entries.map((entry) => 
                          Chip(
                            label: Text(
                              entry.value,
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                          )
                        ).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Products with Categories:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                        ? Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.orange[100]!, Colors.orange[200]!],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Colors.orange[600],
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    product['name'],
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.blue[200]!, width: 0.5),
                                            ),
                                            child: Text(
                                              product['categoryName'],
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                          if (product['isUpcycled'] == true) ...[
                                            SizedBox(width: 6),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'UPCYCLED',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'ID: ${product['categoryID']} • ₱${product['price']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
