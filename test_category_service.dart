import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/category_service.dart';

// Simple test to manually check category service
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Testing CategoryService...');
  
  try {
    // Test basic Firestore connection
    print('Testing Firestore connection...');
    final testDoc = await FirebaseFirestore.instance
        .collection('test')
        .doc('test')
        .get();
    print('Firestore connection: OK');
    
    // Test category initialization
    print('Testing category initialization...');
    final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
    print('Categories already initialized: $isInitialized');
    
    if (!isInitialized) {
      print('Initializing categories...');
      await CategoryService.initializeDefaultCategories();
      print('Initialization completed');
    }
    
    // Test category retrieval
    print('Fetching categories...');
    final categories = await CategoryService.getAllProductCategories();
    print('Found ${categories.length} categories');
    
    for (final category in categories) {
      print('Category: ${category['name']} -> ${category['displayName']}');
    }
    
    print('CategoryService test completed successfully!');
    
  } catch (e, stackTrace) {
    print('CategoryService test failed: $e');
    print('Stack trace: $stackTrace');
  }
}
