import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lib/services/category_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== CATEGORY DATABASE INITIALIZATION ===');
  
  try {
    // Check if categories exist
    print('1. Checking if default categories exist...');
    bool exist = await CategoryService.areDefaultCategoriesInitialized();
    print('   Categories exist: $exist');
    
    if (!exist) {
      print('2. Initializing default categories...');
      await CategoryService.initializeDefaultCategories();
      print('   ✅ Categories initialized successfully!');
    } else {
      print('2. Categories already exist, skipping initialization');
    }
    
    // Get all categories to verify
    print('3. Loading all categories from database...');
    final categories = await CategoryService.getAllProductCategories();
    print('   Found ${categories.length} categories');
    
    print('\n=== CATEGORY LIST ===');
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      print('${i + 1}. ${cat['displayName']} (${cat['name']})');
      print('   Description: ${cat['description']}');
      print('   Created by: ${cat['createdBy']}');
      print('');
    }
    
    // Check Firestore collection directly
    print('4. Direct Firestore verification...');
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'product')
        .get();
    
    print('   Direct query found ${snapshot.docs.length} product categories');
    
    print('\n✅ INITIALIZATION COMPLETE');
    print('Categories are ready to use in the app!');
    
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
