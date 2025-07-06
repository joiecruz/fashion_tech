import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple service for populating the colors collection with default colors
class ColorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _colorsCollection = 'colors';

  /// Default colors to populate in the database
  static final List<Map<String, String>> _defaultColors = [
    // Basic Colors
    {'name': 'Black', 'hexCode': '#000000'},
    {'name': 'White', 'hexCode': '#FFFFFF'},
    {'name': 'Gray', 'hexCode': '#808080'},
    {'name': 'Light Gray', 'hexCode': '#D3D3D3'},
    {'name': 'Dark Gray', 'hexCode': '#404040'},
    
    // Red Tones
    {'name': 'Red', 'hexCode': '#FF0000'},
    {'name': 'Dark Red', 'hexCode': '#8B0000'},
    {'name': 'Light Red', 'hexCode': '#FFB6C1'},
    {'name': 'Maroon', 'hexCode': '#800000'},
    {'name': 'Crimson', 'hexCode': '#DC143C'},
    
    // Blue Tones
    {'name': 'Blue', 'hexCode': '#0000FF'},
    {'name': 'Navy Blue', 'hexCode': '#000080'},
    {'name': 'Light Blue', 'hexCode': '#ADD8E6'},
    {'name': 'Royal Blue', 'hexCode': '#4169E1'},
    {'name': 'Sky Blue', 'hexCode': '#87CEEB'},
    {'name': 'Teal', 'hexCode': '#008080'},
    
    // Green Tones
    {'name': 'Green', 'hexCode': '#008000'},
    {'name': 'Dark Green', 'hexCode': '#006400'},
    {'name': 'Light Green', 'hexCode': '#90EE90'},
    {'name': 'Forest Green', 'hexCode': '#228B22'},
    {'name': 'Olive Green', 'hexCode': '#808000'},
    {'name': 'Lime Green', 'hexCode': '#32CD32'},
    
    // Yellow/Orange Tones
    {'name': 'Yellow', 'hexCode': '#FFFF00'},
    {'name': 'Light Yellow', 'hexCode': '#FFFFE0'},
    {'name': 'Gold', 'hexCode': '#FFD700'},
    {'name': 'Orange', 'hexCode': '#FFA500'},
    {'name': 'Dark Orange', 'hexCode': '#FF8C00'},
    {'name': 'Light Orange', 'hexCode': '#FFE4B5'},
    
    // Purple/Pink Tones
    {'name': 'Purple', 'hexCode': '#800080'},
    {'name': 'Light Purple', 'hexCode': '#DDA0DD'},
    {'name': 'Violet', 'hexCode': '#8A2BE2'},
    {'name': 'Pink', 'hexCode': '#FFC0CB'},
    {'name': 'Hot Pink', 'hexCode': '#FF69B4'},
    {'name': 'Light Pink', 'hexCode': '#FFB6C1'},
    
    // Brown/Earth Tones
    {'name': 'Brown', 'hexCode': '#A52A2A'},
    {'name': 'Light Brown', 'hexCode': '#D2B48C'},
    {'name': 'Dark Brown', 'hexCode': '#654321'},
    {'name': 'Tan', 'hexCode': '#D2B48C'},
    {'name': 'Beige', 'hexCode': '#F5F5DC'},
    {'name': 'Cream', 'hexCode': '#FFFDD0'},
    {'name': 'Ivory', 'hexCode': '#FFFFF0'},
    
    // Additional Colors
    {'name': 'Turquoise', 'hexCode': '#40E0D0'},
    {'name': 'Cyan', 'hexCode': '#00FFFF'},
    {'name': 'Silver', 'hexCode': '#C0C0C0'},
    {'name': 'Coral', 'hexCode': '#FF7F50'},
    {'name': 'Salmon', 'hexCode': '#FA8072'},
    {'name': 'Khaki', 'hexCode': '#F0E68C'},
    {'name': 'Lavender', 'hexCode': '#E6E6FA'},
    {'name': 'Mint', 'hexCode': '#98FB98'},
    {'name': 'Peach', 'hexCode': '#FFCBA4'},
    {'name': 'Rose', 'hexCode': '#FF66CC'},
  ];

  /// Check if default colors have been initialized
  static Future<bool> areDefaultColorsInitialized() async {
    try {
      final snapshot = await _firestore.collection(_colorsCollection).limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking default colors: $e');
      return false;
    }
  }

  /// Initialize default colors in the database
  static Future<void> initializeDefaultColors() async {
    try {
      // Check if colors already exist
      final existingCheck = await areDefaultColorsInitialized();
      if (existingCheck) {
        print('Default colors already exist, skipping initialization');
        return;
      }

      // Add each color to the database
      final batch = _firestore.batch();
      
      for (final colorData in _defaultColors) {
        final docRef = _firestore.collection(_colorsCollection).doc();
        batch.set(docRef, {
          'name': colorData['name'],
          'hexCode': colorData['hexCode'],
          'createdAt': FieldValue.serverTimestamp(),
          'isDefault': true, // Mark as default color
        });
      }

      await batch.commit();
      print('Successfully initialized ${_defaultColors.length} default colors');
    } catch (e) {
      print('Error initializing default colors: $e');
      rethrow;
    }
  }

  /// Get all colors from the database
  static Future<List<Map<String, dynamic>>> getAllColors() async {
    try {
      final snapshot = await _firestore.collection(_colorsCollection).get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting colors: $e');
      return [];
    }
  }
}
