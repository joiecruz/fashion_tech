import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Test writing to productImages collection
  try {
    print('Testing Firestore write to productImages collection...');
    
    final productImageRef = FirebaseFirestore.instance.collection('productImages').doc();
    
    final testData = {
      'productID': 'test-product-123',
      'imageURL': 'https://example.com/test-image.jpg',
      'isPrimary': true,
      'uploadedBy': 'test-user',
      'uploadedAt': DateTime.now(),
    };
    
    print('Attempting to write data: $testData');
    await productImageRef.set(testData);
    print('SUCCESS: Test document written with ID: ${productImageRef.id}');
    
    // Try to read it back
    final doc = await productImageRef.get();
    if (doc.exists) {
      print('SUCCESS: Document read back successfully: ${doc.data()}');
    } else {
      print('ERROR: Document was not found after writing');
    }
    
  } catch (e) {
    print('ERROR: Failed to write to productImages collection: $e');
  }
}
