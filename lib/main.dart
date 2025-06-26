import 'package:flutter/material.dart';
import 'add_job_order_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Tech',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AddJobOrderPage(),
    );
  }
}