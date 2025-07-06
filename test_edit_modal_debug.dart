// Test script to verify job order edit modal functionality
// This would help identify if there are any issues with data fetching

import 'package:flutter/material.dart';
import 'lib/frontend/job_orders/job_order_edit_modal.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Order Edit Modal Test',
      home: TestPage(),
    );
  }
}

class TestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Job Order Edit Modal'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Test with a dummy job order ID
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Container(
                margin: const EdgeInsets.only(top: 100),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: JobOrderEditModal(jobOrderId: "test-job-order-id"),
              ),
            );
          },
          child: Text('Open Edit Modal'),
        ),
      ),
    );
  }
}
