import 'package:flutter/material.dart';

/// A gradient search bar component that provides consistent styling across the app
/// Follows responsive design principles and adapts to different screen sizes
class GradientSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Color primaryColor;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final bool isCompact;
  final double? width;

  const GradientSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon = Icons.search,
    this.primaryColor = Colors.orange,
    this.onClear,
    this.onChanged,
    this.isCompact = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // Calculate responsive dimensions
    final double horizontalPadding = isMobile ? 12 : (isTablet ? 16 : 20);
    final double verticalPadding = isCompact 
        ? (isMobile ? 10 : 12)
        : (isMobile ? 14 : 16);
    final double borderRadius = isMobile ? 12 : (isCompact ? 14 : 16);
    final double iconSize = isMobile ? 20 : 22;
    final double fontSize = isMobile ? 14 : 16;

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(primaryColor),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _getBorderColor(primaryColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.grey[800],
          height: 1.0, // Better text alignment
        ),
        textAlignVertical: TextAlignVertical.center, // Center text vertically
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: fontSize,
            height: 1.0, // Better hint text alignment
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Colors.grey[600],
            size: iconSize,
          ),
          suffixIcon: controller.text.isNotEmpty && onClear != null
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[600],
                    size: iconSize,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          isDense: true, // Makes the text field more compact and centered
        ),
      ),
    );
  }

  /// Get appropriate gradient colors based on the primary color
  List<Color> _getGradientColors(Color primaryColor) {
    if (primaryColor == Colors.orange) {
      return [Colors.orange.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.blue) {
      return [Colors.blue.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.green) {
      return [Colors.green.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.purple) {
      return [Colors.purple.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.pink) {
      return [Colors.pink.shade50, Colors.grey.shade50]; // Softer pink gradient
    } else if (primaryColor == Colors.teal) {
      return [Colors.teal.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.red) {
      return [Colors.red.shade50, Colors.grey.shade100];
    } else if (primaryColor == Colors.indigo) {
      return [Colors.indigo.shade50, Colors.grey.shade100];
    } else {
      // Default gradient for custom colors
      return [
        primaryColor.withOpacity(0.08),
        Colors.grey.shade100,
      ];
    }
  }

  /// Get appropriate border color based on the primary color
  Color _getBorderColor(Color primaryColor) {
    if (primaryColor == Colors.orange) {
      return Colors.orange.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.blue) {
      return Colors.blue.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.green) {
      return Colors.green.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.purple) {
      return Colors.purple.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.pink) {
      return Colors.pink.shade100.withOpacity(0.3); // Softer pink border
    } else if (primaryColor == Colors.teal) {
      return Colors.teal.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.red) {
      return Colors.red.shade200.withOpacity(0.4);
    } else if (primaryColor == Colors.indigo) {
      return Colors.indigo.shade200.withOpacity(0.4);
    } else {
      // Default border for custom colors
      return primaryColor.withOpacity(0.3);
    }
  }
}

/// A compact version of the gradient search bar for use in smaller spaces
class CompactGradientSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Color primaryColor;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final double? width;

  const CompactGradientSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon = Icons.search,
    this.primaryColor = Colors.orange,
    this.onClear,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GradientSearchBar(
      controller: controller,
      hintText: hintText,
      prefixIcon: prefixIcon,
      primaryColor: primaryColor,
      onClear: onClear,
      onChanged: onChanged,
      isCompact: true,
      width: width,
    );
  }
}

/// A compact gradient filter chip component for responsive filter UI
class GradientFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final IconData? icon;

  const GradientFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.primaryColor = Colors.orange,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    final double fontSize = isMobile ? 12 : 14;
    final double padding = isMobile ? 8 : 12;
    final double iconSize = isMobile ? 14 : 16;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: isMobile ? 6 : 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: _getSelectedGradient(primaryColor),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )          : LinearGradient(
              colors: [Colors.grey.shade100, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          border: Border.all(
            color: isSelected 
                ? primaryColor.withOpacity(0.3)
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: iconSize,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              SizedBox(width: isMobile ? 4 : 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getSelectedGradient(Color primaryColor) {
    if (primaryColor == Colors.orange) {
      return [Colors.orange.shade400, Colors.orange.shade600];
    } else if (primaryColor == Colors.blue) {
      return [Colors.blue.shade400, Colors.blue.shade600];
    } else if (primaryColor == Colors.green) {
      return [Colors.green.shade400, Colors.green.shade600];
    } else if (primaryColor == Colors.purple) {
      return [Colors.purple.shade400, Colors.purple.shade600];
    } else if (primaryColor == Colors.pink) {
      return [Colors.pink.shade400, Colors.pink.shade600];
    } else if (primaryColor == Colors.teal) {
      return [Colors.teal.shade400, Colors.teal.shade600];
    } else if (primaryColor == Colors.red) {
      return [Colors.red.shade400, Colors.red.shade600];
    } else if (primaryColor == Colors.indigo) {
      return [Colors.indigo.shade400, Colors.indigo.shade600];
    } else {
      return [primaryColor, primaryColor.withOpacity(0.8)];
    }
  }
}
