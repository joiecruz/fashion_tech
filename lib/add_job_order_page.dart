import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddJobOrderPage extends StatefulWidget {
  const AddJobOrderPage({super.key});

  @override
  State<AddJobOrderPage> createState() => _AddJobOrderPageState();
}

class _AddJobOrderPageState extends State<AddJobOrderPage> {
  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  double? profit;
  bool isLoading = false;

  Future<double?> fetchProfit({
    required String productID,
    required int quantity,
  }) async {
    final url = Uri.parse('http://your-backend-url/api/profit-checker'); // Replace with your backend URL
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'productID': productID, 'quantity': quantity}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['profit'] as num?)?.toDouble();
    }
    return null;
  }

  Future<void> checkProfit() async {
    setState(() => isLoading = true);
    final productID = _productIdController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final result = await fetchProfit(productID: productID, quantity: quantity);
    setState(() {
      profit = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Job Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _productIdController,
              decoration: const InputDecoration(
                labelText: 'Product ID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : checkProfit,
              child: const Text('Check Profit'),
            ),
            const SizedBox(height: 24),
            if (isLoading) const CircularProgressIndicator(),
            if (profit != null)
              Text(
                'Profit: \$${profit!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}