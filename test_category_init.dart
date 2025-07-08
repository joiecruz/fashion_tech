import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/category_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // Check current categories
    print('\n🔍 Checking current categories in database...');
    final categories = await CategoryService.getAllProductCategories();
    print('Found ${categories.length} categories in database:');
    
    for (final category in categories) {
      print('  - ${category['displayName']} (${category['name']}) - Created by: ${category['createdBy']}');
    }
    
    // Initialize categories if needed
    print('\n🔄 Checking if initialization is needed...');
    final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
    print('Categories already initialized: $isInitialized');
    
    if (!isInitialized) {
      print('\n🚀 Initializing default categories...');
      await CategoryService.initializeDefaultCategories();
      
      // Check again after initialization
      final newCategories = await CategoryService.getAllProductCategories();
      print('\n✅ After initialization, found ${newCategories.length} categories:');
      for (final category in newCategories) {
        print('  - ${category['displayName']} (${category['name']}) - ${category['description']}');
      }
    } else {
      print('\n✅ Categories already exist, no initialization needed');
    }
    
    print('\n🎉 Category check complete!');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
