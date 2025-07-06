import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/color.dart' as ColorModel;

/// Service to initialize and manage default colors in the database
class DefaultColorsService {
  static const String _systemUser = 'SYSTEM_DEFAULT';
  
  /// Default colors with their hex codes
  static final List<Map<String, dynamic>> _defaultColors = [
    {'name': 'Black', 'hexCode': '#000000'},
    {'name': 'White', 'hexCode': '#FFFFFF'},
    {'name': 'Gray', 'hexCode': '#808080'},
    {'name': 'Light Gray', 'hexCode': '#D3D3D3'},
    {'name': 'Dark Gray', 'hexCode': '#404040'},
    {'name': 'Red', 'hexCode': '#FF0000'},
    {'name': 'Dark Red', 'hexCode': '#8B0000'},
    {'name': 'Light Red', 'hexCode': '#FFB6C1'},
    {'name': 'Blue', 'hexCode': '#0000FF'},
    {'name': 'Navy Blue', 'hexCode': '#000080'},
    {'name': 'Light Blue', 'hexCode': '#ADD8E6'},
    {'name': 'Royal Blue', 'hexCode': '#4169E1'},
    {'name': 'Sky Blue', 'hexCode': '#87CEEB'},
    {'name': 'Green', 'hexCode': '#008000'},
    {'name': 'Dark Green', 'hexCode': '#006400'},
    {'name': 'Light Green', 'hexCode': '#90EE90'},
    {'name': 'Forest Green', 'hexCode': '#228B22'},
    {'name': 'Olive Green', 'hexCode': '#808000'},
    {'name': 'Yellow', 'hexCode': '#FFFF00'},
    {'name': 'Light Yellow', 'hexCode': '#FFFFE0'},
    {'name': 'Gold', 'hexCode': '#FFD700'},
    {'name': 'Pink', 'hexCode': '#FFC0CB'},
    {'name': 'Hot Pink', 'hexCode': '#FF69B4'},
    {'name': 'Light Pink', 'hexCode': '#FFB6C1'},
    {'name': 'Purple', 'hexCode': '#800080'},
    {'name': 'Light Purple', 'hexCode': '#DDA0DD'},
    {'name': 'Violet', 'hexCode': '#8A2BE2'},
    {'name': 'Brown', 'hexCode': '#A52A2A'},
    {'name': 'Light Brown', 'hexCode': '#D2B48C'},
    {'name': 'Dark Brown', 'hexCode': '#654321'},
    {'name': 'Orange', 'hexCode': '#FFA500'},
    {'name': 'Light Orange', 'hexCode': '#FFE4B5'},
    {'name': 'Dark Orange', 'hexCode': '#FF8C00'},
    {'name': 'Beige', 'hexCode': '#F5F5DC'},
    {'name': 'Cream', 'hexCode': '#FFFDD0'},
    {'name': 'Ivory', 'hexCode': '#FFFFF0'},
    {'name': 'Maroon', 'hexCode': '#800000'},
    {'name': 'Teal', 'hexCode': '#008080'},
    {'name': 'Turquoise', 'hexCode': '#40E0D0'},
    {'name': 'Cyan', 'hexCode': '#00FFFF'},
    {'name': 'Silver', 'hexCode': '#C0C0C0'},
    {'name': 'Magenta', 'hexCode': '#FF00FF'},
    {'name': 'Indigo', 'hexCode': '#4B0082'},
    {'name': 'Coral', 'hexCode': '#FF7F50'},
    {'name': 'Salmon', 'hexCode': '#FA8072'},
    {'name': 'Khaki', 'hexCode': '#F0E68C'},
    {'name': 'Mint', 'hexCode': '#98FB98'},
    {'name': 'Peach', 'hexCode': '#FFCBA4'},
    {'name': 'Lavender', 'hexCode': '#E6E6FA'},
    {'name': 'Multi-Color', 'hexCode': '#FF6B6B'}, // Special case for multi-colored items
  ];

  /// Initialize default colors in the database
  static Future<void> initializeDefaultColors() async {
    try {
      print('[DEBUG] Initializing default colors in database...');
      
      final colorsCollection = FirebaseFirestore.instance.collection('colors');
      
      // Check if default colors already exist
      final existingColors = await colorsCollection
          .where('createdBy', isEqualTo: _systemUser)
          .get();
      
      if (existingColors.docs.isNotEmpty) {
        print('[DEBUG] Default colors already exist. Skipping initialization.');
        return;
      }
      
      // Add default colors
      final batch = FirebaseFirestore.instance.batch();
      
      for (final colorData in _defaultColors) {
        final colorRef = colorsCollection.doc();
        batch.set(colorRef, {
          'name': colorData['name'],
          'hexCode': colorData['hexCode'],
          'createdBy': _systemUser,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('[DEBUG] Successfully initialized ${_defaultColors.length} default colors');
      
    } catch (e) {
      print('[ERROR] Failed to initialize default colors: $e');
      rethrow;
    }
  }

  /// Get all available colors (system defaults + user-created)
  static Future<List<ColorModel.Color>> getAllColors() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colors')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => 
        ColorModel.Color.fromMap(doc.id, doc.data())
      ).toList();
      
    } catch (e) {
      print('[ERROR] Failed to fetch colors: $e');
      return [];
    }
  }

  /// Get colors available to a specific user (system defaults + user's colors)
  static Future<List<ColorModel.Color>> getAvailableColors(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colors')
          .where('createdBy', whereIn: [_systemUser, userId])
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => 
        ColorModel.Color.fromMap(doc.id, doc.data())
      ).toList();
      
    } catch (e) {
      print('[ERROR] Failed to fetch available colors for user $userId: $e');
      return [];
    }
  }

  /// Check if default colors are initialized
  static Future<bool> areDefaultColorsInitialized() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colors')
          .where('createdBy', isEqualTo: _systemUser)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('[ERROR] Failed to check default colors: $e');
      return false;
    }
  }

  /// Get a color by ID
  static Future<ColorModel.Color?> getColorById(String colorId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colors')
          .doc(colorId)
          .get();
      
      if (doc.exists) {
        return ColorModel.Color.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('[ERROR] Failed to fetch color by ID $colorId: $e');
      return null;
    }
  }

  /// Create a new color for a user
  static Future<String?> createColor(String name, String hexCode, String userId) async {
    try {
      final colorRef = FirebaseFirestore.instance.collection('colors').doc();
      
      await colorRef.set({
        'name': name,
        'hexCode': hexCode,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return colorRef.id;
    } catch (e) {
      print('[ERROR] Failed to create color: $e');
      return null;
    }
  }
}
