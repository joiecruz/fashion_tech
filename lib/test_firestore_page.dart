import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreTestPage extends StatefulWidget {
  @override
  _FirestoreTestPageState createState() => _FirestoreTestPageState();
}

class _FirestoreTestPageState extends State<FirestoreTestPage> {
  String _testResult = 'Not tested yet';

  Future<void> _testFirestoreWrite() async {
    setState(() {
      _testResult = 'Testing...';
    });

    try {
      // Test writing to products collection (which we know works)
      final productRef = FirebaseFirestore.instance.collection('products').doc();
      await productRef.set({
        'name': 'Test Product',
        'price': 100.0,
        'category': 'test',
        'isUpcycled': false,
        'isMade': false,
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      // Test writing to productImages collection
      final imageRef = FirebaseFirestore.instance.collection('productImages').doc();
      await imageRef.set({
        'productID': productRef.id,
        'imageURL': 'https://example.com/test.jpg',
        'isPrimary': true,
        'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        'uploadedAt': Timestamp.fromDate(DateTime.now()),
      });

      setState(() {
        _testResult = 'SUCCESS! Both collections work.\nProduct ID: ${productRef.id}\nImage ID: ${imageRef.id}';
      });
    } catch (e) {
      setState(() {
        _testResult = 'ERROR: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firestore Test')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _testFirestoreWrite,
              child: Text('Test Firestore Write'),
            ),
            SizedBox(height: 20),
            Text(_testResult),
          ],
        ),
      ),
    );
  }
}
