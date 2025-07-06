import 'package:flutter/material.dart';
import '../../services/color_service.dart';

/// Simple, safe color dropdown that avoids stack overflow issues
class SimpleColorDropdown extends StatefulWidget {
  final String? selectedColor;
  final Function(String?) onChanged;
  final bool isRequired;
  final FormFieldValidator<String>? validator;

  const SimpleColorDropdown({
    super.key,
    this.selectedColor,
    required this.onChanged,
    this.isRequired = false,
    this.validator,
  });

  @override
  State<SimpleColorDropdown> createState() => _SimpleColorDropdownState();
}

class _SimpleColorDropdownState extends State<SimpleColorDropdown> {
  List<Map<String, dynamic>> _colors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    try {
      // Initialize colors if needed
      final isInitialized = await ColorService.areDefaultColorsInitialized();
      if (!isInitialized) {
        await ColorService.initializeDefaultColors();
      }

      // Get colors from service with hex codes
      final colors = await ColorService.getAllColors();
      if (mounted) {
        setState(() {
          _colors = colors;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading colors: $e');
      if (mounted) {
        setState(() {
          // Fallback to default colors with hex codes
          _colors = [
            {'name': 'Black', 'hexCode': '#000000'},
            {'name': 'White', 'hexCode': '#FFFFFF'},
            {'name': 'Red', 'hexCode': '#FF0000'},
            {'name': 'Blue', 'hexCode': '#0000FF'},
            {'name': 'Green', 'hexCode': '#008000'},
            {'name': 'Yellow', 'hexCode': '#FFFF00'},
            {'name': 'Orange', 'hexCode': '#FFA500'},
            {'name': 'Purple', 'hexCode': '#800080'},
            {'name': 'Pink', 'hexCode': '#FFC0CB'},
            {'name': 'Brown', 'hexCode': '#A52A2A'},
            {'name': 'Gray', 'hexCode': '#808080'},
            {'name': 'Navy Blue', 'hexCode': '#000080'},
            {'name': 'Maroon', 'hexCode': '#800000'},
          ];
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String? hexCode) {
    if (hexCode == null || hexCode.isEmpty) return Colors.grey;
    
    // Parse hex code directly to avoid circular dependency
    try {
      String hex = hexCode.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildColorIndicator(String colorName, String? hexCode) {
    final color = _parseColor(hexCode);
    final needsBorder = color.computeLuminance() > 0.8 || colorName.toLowerCase().contains('white');

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: needsBorder 
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _colors.any((color) => color['name'] == widget.selectedColor) ? widget.selectedColor : null,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintText: 'Select a color',
      ),
      items: _colors.map((color) {
        final colorName = color['name'] as String;
        final hexCode = color['hexCode'] as String?;
        
        return DropdownMenuItem<String>(
          value: colorName,
          child: Row(
            children: [
              _buildColorIndicator(colorName, hexCode),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  colorName,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      validator: widget.validator ?? (widget.isRequired 
          ? (value) => value == null || value.isEmpty ? 'Please select a color' : null
          : null),
      onChanged: widget.onChanged,
    );
  }
}
