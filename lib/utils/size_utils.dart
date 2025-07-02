import 'package:flutter/material.dart';

/// Universal size utilities for the Fashion Tech app
/// Provides consistent size options and visual indicators across all modals and components
class SizeUtils {
  // Universal size options for the app
  static const List<String> sizeOptions = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', 'Free Size'
  ];

  // Alternative size names mapping for compatibility
  static const Map<String, String> sizeAliases = {
    'Extra Small': 'XS',
    'Small': 'S',
    'Medium': 'M',
    'Large': 'L',
    'Extra Large': 'XL',
    'XXL': 'XXL',
    'XXXL': 'XXXL',
    'One Size': 'Free Size',
    'Free Size': 'Free Size',
    'OS': 'Free Size',
    'OneSize': 'Free Size',
  };

  // Size descriptions for better UX
  static const Map<String, String> sizeDescriptions = {
    'XS': 'Extra Small',
    'S': 'Small',
    'M': 'Medium',
    'L': 'Large',
    'XL': 'Extra Large',
    'XXL': 'Double XL',
    'XXXL': 'Triple XL',
    'Free Size': 'One Size Fits All',
  };

  // Color coding for size indicators (optional visual enhancement)
  static const Map<String, Color> sizeColors = {
    'XS': Color(0xFFE3F2FD), // Light blue
    'S': Color(0xFFE8F5E8),  // Light green
    'M': Color(0xFFFFF3E0),  // Light orange
    'L': Color(0xFFFCE4EC),  // Light pink
    'XL': Color(0xFFF3E5F5), // Light purple
    'XXL': Color(0xFFEDE7F6), // Light deep purple
    'XXXL': Color(0xFFE1F5FE), // Light cyan
    'Free Size': Color(0xFFF5F5F5), // Light grey
  };

  // Text colors for size indicators
  static const Map<String, Color> sizeTextColors = {
    'XS': Color(0xFF1976D2),
    'S': Color(0xFF388E3C),
    'M': Color(0xFFF57C00),
    'L': Color(0xFFE91E63),
    'XL': Color(0xFF7B1FA2),
    'XXL': Color(0xFF512DA8),
    'XXXL': Color(0xFF0288D1),
    'Free Size': Color(0xFF616161),
  };

  /// Creates a size indicator widget with consistent styling
  /// 
  /// [size] - The size name to display
  /// [showDescription] - Whether to show the full description (default: false)
  /// [compact] - Whether to use compact styling (default: false)
  static Widget buildSizeIndicator(String size, {
    bool showDescription = false,
    bool compact = false,
  }) {
    final backgroundColor = sizeColors[size] ?? Colors.grey.shade100;
    final textColor = sizeTextColors[size] ?? Colors.grey.shade700;
    final displayText = showDescription ? (sizeDescriptions[size] ?? size) : size;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Creates a size indicator with optional description
  /// 
  /// [size] - The size name to display
  /// [showBothSizeAndDescription] - Whether to show both size and description
  /// [spacing] - Space between size and description (default: 8)
  static Widget buildSizeIndicatorWithDescription(String size, {
    bool showBothSizeAndDescription = false,
    double spacing = 8,
  }) {
    if (!showBothSizeAndDescription) {
      return buildSizeIndicator(size);
    }

    final description = sizeDescriptions[size];
    if (description == null || description == size) {
      return buildSizeIndicator(size);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildSizeIndicator(size, compact: true),
        SizedBox(width: spacing),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Normalizes a size value to the standard format
  /// 
  /// [inputSize] - The size value to normalize
  /// [fallback] - Fallback size if normalization fails (default: 'M')
  static String normalizeSize(String inputSize, {String fallback = 'M'}) {
    // Direct match
    if (sizeOptions.contains(inputSize)) {
      return inputSize;
    }

    // Check aliases
    final normalized = sizeAliases[inputSize];
    if (normalized != null && sizeOptions.contains(normalized)) {
      return normalized;
    }

    // Case-insensitive check
    final lowerInput = inputSize.toLowerCase().trim();
    for (final alias in sizeAliases.keys) {
      if (alias.toLowerCase() == lowerInput) {
        final normalizedSize = sizeAliases[alias]!;
        if (sizeOptions.contains(normalizedSize)) {
          return normalizedSize;
        }
      }
    }

    // Check direct options (case-insensitive)
    for (final option in sizeOptions) {
      if (option.toLowerCase() == lowerInput) {
        return option;
      }
    }

    return fallback;
  }

  /// Creates dropdown menu items for size selection with visual indicators
  /// 
  /// [showDescriptions] - Whether to show size descriptions (default: true)
  static List<DropdownMenuItem<String>> buildSizeDropdownItems({
    bool showDescriptions = true,
  }) {
    return sizeOptions.map((size) {
      return DropdownMenuItem(
        value: size,
        child: buildSizeIndicatorWithDescription(
          size,
          showBothSizeAndDescription: showDescriptions,
        ),
      );
    }).toList();
  }

  /// Creates selected item builder for size dropdown with consistent styling
  /// 
  /// [context] - Build context
  /// [compact] - Whether to use compact styling (default: true)
  static List<Widget> buildSizeSelectedItems(BuildContext context, {bool compact = true}) {
    return sizeOptions.map((size) {
      return buildSizeIndicator(size, compact: compact);
    }).toList();
  }

  /// Validates if a size name exists in our size system
  /// 
  /// [sizeName] - The size name to validate
  static bool isValidSize(String sizeName) {
    return sizeOptions.contains(sizeName) || sizeAliases.containsKey(sizeName);
  }

  /// Gets all available size names
  static List<String> getAllSizeNames() {
    return List.from(sizeOptions);
  }

  /// Gets the description for a size
  /// 
  /// [size] - The size to get description for
  static String? getSizeDescription(String size) {
    return sizeDescriptions[size];
  }

  /// Creates a size selection chip widget
  /// 
  /// [size] - The size name
  /// [isSelected] - Whether the size is currently selected
  /// [onTap] - Callback when the chip is tapped
  static Widget buildSizeChip({
    required String size,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isSelected 
        ? (sizeColors[size] ?? Colors.blue.shade100)
        : Colors.grey.shade50;
    final textColor = isSelected
        ? (sizeTextColors[size] ?? Colors.blue.shade700)
        : Colors.grey.shade600;
    final borderColor = isSelected
        ? (sizeTextColors[size] ?? Colors.blue.shade700)
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Text(
          size,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
