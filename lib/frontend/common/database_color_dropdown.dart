import 'package:flutter/material.dart';
import '../../services/color_service.dart';
import '../../utils/color_utils.dart';

/// Enhanced color dropdown that loads colors from database with better UX
class DatabaseColorDropdown extends StatefulWidget {
  final String? selectedColor;
  final Function(String?) onChanged;
  final String? label;
  final bool isRequired;
  final String? hintText;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;

  const DatabaseColorDropdown({
    super.key,
    this.selectedColor,
    required this.onChanged,
    this.label,
    this.isRequired = false,
    this.hintText,
    this.decoration,
    this.validator,
  });

  @override
  State<DatabaseColorDropdown> createState() => _DatabaseColorDropdownState();
}

class _DatabaseColorDropdownState extends State<DatabaseColorDropdown> {
  List<Map<String, dynamic>> _colors = [];
  bool _isLoading = true;
  String? _selectedColor;
  bool _isUpdating = false; // Prevent recursive updates

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
    _loadColors();
  }

  @override
  void didUpdateWidget(DatabaseColorDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUpdating && oldWidget.selectedColor != widget.selectedColor && _selectedColor != widget.selectedColor) {
      setState(() {
        _selectedColor = widget.selectedColor;
      });
    }
  }

  Future<void> _loadColors() async {
    if (!mounted || _isUpdating) return;
    
    try {
      // Initialize colors if needed
      final isInitialized = await ColorService.areDefaultColorsInitialized();
      if (!mounted) return;
      
      if (!isInitialized) {
        await ColorService.initializeDefaultColors();
        if (!mounted) return;
      }

      final colors = await ColorService.getAllColors();
      if (mounted && !_isUpdating) {
        setState(() {
          _colors = colors;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading colors: $e');
      if (mounted && !_isUpdating) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String? hexCode) {
    if (hexCode == null) return Colors.grey;
    return ColorUtils.parseColor(hexCode);
  }

  Widget _buildColorIndicator(String colorName, String? hexCode, {double size = 20}) {
    final color = _parseColor(hexCode);
    final needsBorder = color.computeLuminance() > 0.8 || colorName.toLowerCase().contains('white');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: needsBorder 
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
    );
  }

  Widget _buildColorIndicatorWithLabel(String colorName, String? hexCode, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColorIndicator(colorName, hexCode, size: size),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            colorName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
          ],
          Container(
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
          ),
        ],
      );
    }

    if (_colors.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.orange.shade50,
            ),
            child: const Center(
              child: Text(
                'No colors available. Please initialize default colors.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          value: _colors.any((color) => color['name'] == _selectedColor) ? _selectedColor : null,
          isExpanded: true,
          decoration: widget.decoration ?? InputDecoration(
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
            hintText: widget.hintText ?? 'Select a color',
          ),
          selectedItemBuilder: (context) {
            return _colors.map((color) {
              final colorName = color['name'] as String;
              final hexCode = color['hexCode'] as String?;
              
              // Only show the selected item if it matches
              if (colorName == _selectedColor) {
                return _buildColorIndicatorWithLabel(
                  colorName,
                  hexCode,
                  size: 16,
                );
              } else {
                // Return empty container for non-selected items
                return Container();
              }
            }).toList();
          },
          items: _colors.map((color) {
            final colorName = color['name'] as String;
            final hexCode = color['hexCode'] as String?;
            final isDefault = color['isDefault'] == true;
            
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
                  if (isDefault) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          validator: widget.validator ?? (widget.isRequired 
              ? (value) => value == null || value.isEmpty ? 'Please select a color' : null
              : null),
          onChanged: (String? colorName) {
            if (!_isUpdating && _selectedColor != colorName) {
              _isUpdating = true;
              setState(() {
                _selectedColor = colorName;
              });
              widget.onChanged(colorName);
              // Reset the flag after a short delay
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted) {
                  _isUpdating = false;
                }
              });
            }
          },
        ),
      ],
    );
  }
}
