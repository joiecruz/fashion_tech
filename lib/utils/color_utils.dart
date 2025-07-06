import 'package:flutter/material.dart';
import '../services/color_service.dart';

/// Universal color utilities for the Fashion Tech app
/// Provides consistent color mapping and visual indicators across all modals and components
class ColorUtils {
  // Cache for database colors
  static List<Map<String, dynamic>> _cachedColors = [];
  static bool _isLoaded = false;

  // Fallback colors (in case database is not available)
  static const List<String> _fallbackColorOptions = [
    'Black', 'White', 'Gray', 'Red', 'Blue', 'Green', 
    'Yellow', 'Pink', 'Purple', 'Brown', 'Orange', 'Navy',
    'Beige', 'Cream', 'Maroon', 'Teal', 'Gold', 'Silver', 'Other'
  ];

  // Universal color mapping for visual indicators (fallback)
  static const Map<String, Color> _fallbackColorMap = {
    'Black': Colors.black,
    'White': Colors.white,
    'Gray': Colors.grey,
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Pink': Colors.pink,
    'Purple': Colors.purple,
    'Brown': Colors.brown,
    'Orange': Colors.orange,
    'Navy': Color(0xFF000080),
    'Beige': Color(0xFFF5F5DC),
    'Cream': Color(0xFFFFFDD0),
    'Maroon': Color(0xFF800000),
    'Teal': Colors.teal,
    'Gold': Color(0xFFFFD700),
    'Silver': Color(0xFFC0C0C0),
    'Other': Color(0xFF9E9E9E), // Colors.grey.shade400 equivalent
  };

  // Colors that need borders for visibility (light colors)
  static const Set<String> lightColors = {
    'White', 'Cream', 'Beige', 'Yellow', 'Silver'
  };

  /// Load colors from database
  static Future<void> _loadColorsFromDatabase() async {
    if (_isLoaded) return;
    
    try {
      _cachedColors = await ColorService.getAllColors();
      _isLoaded = true;
    } catch (e) {
      print('Failed to load colors from database: $e');
      _isLoaded = true; // Mark as loaded to avoid repeated attempts
    }
  }

  /// Get color options (from database or fallback)
  static Future<List<String>> getColorOptions() async {
    await _loadColorsFromDatabase();
    
    if (_cachedColors.isNotEmpty) {
      return _cachedColors.map((color) => color['name'] as String).toList();
    }
    
    return _fallbackColorOptions;
  }

  /// Get color options synchronously (returns cached or fallback)
  static List<String> get colorOptions {
    if (_cachedColors.isNotEmpty) {
      return _cachedColors.map((color) => color['name'] as String).toList();
    }
    return _fallbackColorOptions;
  }

  /// Get color map (from database or fallback)
  static Map<String, Color> get colorMap {
    if (_cachedColors.isNotEmpty) {
      final map = <String, Color>{};
      for (final color in _cachedColors) {
        final name = color['name'] as String;
        final hexCode = color['hexCode'] as String;
        map[name] = _parseHexColor(hexCode);
      }
      return map;
    }
    return _fallbackColorMap;
  }

  /// Creates a color indicator widget with consistent styling
  /// 
  /// [color] - The color name to display
  /// [size] - The size of the color indicator (default: 20)
  /// [showBorder] - Whether to force a border (default: auto-detect for light colors)
  static Widget buildColorIndicator(String color, {
    double size = 20,
    bool? showBorder,
  }) {
    final shouldShowBorder = showBorder ?? lightColors.contains(color);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorMap[color] ?? Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(
          color: shouldShowBorder ? Colors.grey.shade400 : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }

  /// Creates a color indicator with text label
  /// 
  /// [color] - The color name to display
  /// [size] - The size of the color indicator (default: 20)
  /// [spacing] - Space between indicator and text (default: 8)
  static Widget buildColorIndicatorWithLabel(String color, {
    double size = 20,
    double spacing = 8,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildColorIndicator(color, size: size),
        SizedBox(width: spacing),
        Text(color),
      ],
    );
  }

  /// Gets the Color object for a color name
  /// 
  /// [colorName] - The name of the color
  /// [fallback] - Fallback color if name not found (default: Colors.grey)
  static Color getColor(String colorName, {Color fallback = Colors.grey}) {
    return colorMap[colorName] ?? fallback;
  }

  /// Parses various color formats and returns a Color object
  /// Supports:
  /// - Named colors (e.g., 'red', 'blue')
  /// - Hex colors (e.g., '#FF0000', 'FF0000')
  /// - Fashion Tech app color names
  /// 
  /// [colorValue] - The color value to parse
  /// [fallback] - Fallback color if parsing fails (default: Colors.grey)
  static Color parseColor(String colorValue, {Color fallback = Colors.grey}) {
    // First try our color map
    if (colorMap.containsKey(colorValue)) {
      return colorMap[colorValue]!;
    }

    // Try hex color parsing directly (avoid circular dependency)
    if (colorValue.startsWith('#') || RegExp(r'^[0-9A-Fa-f]{6,8}$').hasMatch(colorValue)) {
      return _parseHexColor(colorValue, fallback: fallback);
    }

    // Try common color name mapping (case-insensitive)
    final Map<String, Color> commonColorNames = {
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'brown': Colors.brown,
      'black': Colors.black,
      'white': Colors.white,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'cyan': Colors.cyan,
      'lime': Colors.lime,
      'indigo': Colors.indigo,
      'amber': Colors.amber,
      'cream': const Color(0xFFFFFDD0),
      'beige': const Color(0xFFF5F5DC),
      'navy': const Color(0xFF000080),
      'maroon': const Color(0xFF800000),
      'olive': const Color(0xFF808000),
      'silver': const Color(0xFFC0C0C0),
      'gold': const Color(0xFFFFD700),
    };

    final colorName = colorValue.toLowerCase().trim();
    return commonColorNames[colorName] ?? fallback;
  }

  /// Creates dropdown menu items for color selection with visual indicators
  /// 
  /// [onChanged] - Callback when color is selected
  /// [selectedColor] - Currently selected color (optional)
  static List<DropdownMenuItem<String>> buildColorDropdownItems() {
    return colorOptions.map((color) {
      return DropdownMenuItem(
        value: color,
        child: buildColorIndicatorWithLabel(color),
      );
    }).toList();
  }

  /// Creates selected item builder for color dropdown with smaller indicators
  /// 
  /// [context] - Build context
  /// [size] - Size of the color indicator (default: 16)
  static List<Widget> buildColorSelectedItems(BuildContext context, {double size = 16}) {
    return colorOptions.map((color) {
      return buildColorIndicatorWithLabel(color, size: size);
    }).toList();
  }

  /// Initialize colors from database (should be called early in app lifecycle)
  static Future<void> initializeColors() async {
    await _loadColorsFromDatabase();
  }

  /// Validates if a color name exists in our color system
  /// 
  /// [colorName] - The color name to validate
  static bool isValidColor(String colorName) {
    return colorMap.containsKey(colorName);
  }

  /// Gets all available color names
  static List<String> getAllColorNames() {
    return List.from(colorOptions);
  }

  /// Internal method to parse hex color without circular dependency
  static Color _parseHexColor(String hexCode, {Color fallback = Colors.grey}) {
    if (hexCode.isEmpty) return fallback;
    
    try {
      String hex = hexCode.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return fallback;
    }
  }
}
