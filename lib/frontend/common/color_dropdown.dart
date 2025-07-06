import 'package:flutter/material.dart';
import '../../services/color_service.dart';

/// Simple color dropdown that uses colors from the database
class ColorDropdown extends StatefulWidget {
  final String? selectedColor;
  final Function(String?) onChanged;
  final String? label;

  const ColorDropdown({
    super.key,
    this.selectedColor,
    required this.onChanged,
    this.label,
  });

  @override
  State<ColorDropdown> createState() => _ColorDropdownState();
}

class _ColorDropdownState extends State<ColorDropdown> {
  List<Map<String, dynamic>> _colors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    try {
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
          _isLoading = false;
        });
      }
    }
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
              borderRadius: BorderRadius.circular(8),
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
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No colors available. Initialize default colors first.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
          value: widget.selectedColor,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: 'Select a color',
          ),
          items: _colors.map((color) {
            return DropdownMenuItem<String>(
              value: color['name'], // Use the color name as the value
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _parseColor(color['hexCode']),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(color['name']),
                  if (color['isDefault'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 14, color: Colors.blue),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  Color _parseColor(String? hexCode) {
    if (hexCode == null) return Colors.grey;
    try {
      String colorCode = hexCode.replaceAll('#', '');
      if (colorCode.length == 6) {
        colorCode = 'FF$colorCode';
      }
      return Color(int.parse(colorCode, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}
