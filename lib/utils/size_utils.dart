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

  // Color coding for size indicators with modern, subtle colors
  static const Map<String, Color> sizeColors = {
    'XS': Color(0xFFF8FAFC), // Light slate
    'S': Color(0xFFECFDF5),  // Light emerald
    'M': Color(0xFFFFFBEB),  // Light amber
    'L': Color(0xFFF3E8FF), // Light violet
    'XL': Color(0xFFEEF2FF), // Light indigo
    'XXL': Color(0xFFF1F5F9), // Light slate
    'XXXL': Color(0xFFF0F9FF), // Light sky
    'Free Size': Color(0xFFFDF4FF), // Light fuchsia
  };

  // Text colors for size indicators with better contrast
  static const Map<String, Color> sizeTextColors = {
    'XS': Color(0xFF1F2937), // Dark gray
    'S': Color(0xFF047857),  // Dark green
    'M': Color(0xFFB45309),  // Dark amber
    'L': Color(0xFF6B21A8),  // Dark purple
    'XL': Color(0xFF3730A3), // Dark indigo
    'XXL': Color(0xFF374151), // Dark gray
    'XXXL': Color(0xFF0C4A6E), // Dark sky
    'Free Size': Color(0xFF86198F), // Dark fuchsia
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
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w700,
          letterSpacing: compact ? 0.4 : 0.6,
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
  /// [compact] - Whether to use compact display for constrained spaces (default: false)
  static List<DropdownMenuItem<String>> buildSizeDropdownItems({
    bool showDescriptions = true,
    bool compact = false,
  }) {
    return sizeOptions.map((size) {
      return DropdownMenuItem(
        value: size,
        child: compact
            ? buildSizeIndicator(size, compact: true)
            : buildSizeIndicatorWithDescription(
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

  /// Creates selected item builder for size dropdown with consistent styling
  /// Specifically designed for constrained spaces like variant cards
  /// 
  /// [context] - Build context
  /// [compact] - Whether to use compact styling (default: true)
  /// [maxWidth] - Maximum width constraint for the selected item (default: 100)
  static List<Widget> buildConstrainedSizeSelectedItems(
    BuildContext context, {
    bool compact = true,
    double maxWidth = 100,
  }) {
    return sizeOptions.map((size) {
      return Container(
        alignment: Alignment.centerLeft,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: buildSizeIndicator(size, compact: compact),
      );
    }).toList();
  }

  /// Creates a very compact size indicator for tight spaces
  /// 
  /// [size] - The size name to display
  static Widget buildCompactSizeIndicator(String size) {
    final backgroundColor = sizeColors[size] ?? Colors.grey.shade100;
    final textColor = sizeTextColors[size] ?? Colors.grey.shade700;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.08),
            blurRadius: 1,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: Text(
        size,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
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
