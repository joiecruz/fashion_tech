import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fabric_log_book.dart'; // Make sure this import is present

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Firestore test: Try to read one document from fabricLogs
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('fabricLogs')
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      print('Firestore is working! Found at least one log.');
    } else {
      print('Firestore is working, but no logs found.');
    }
  } catch (e) {
    print('Firestore error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const FabricLogBookScreen(),
    );
  }
}