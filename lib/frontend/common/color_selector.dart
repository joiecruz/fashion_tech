import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/color.dart' as ColorModel;
import '../../services/default_colors_service.dart';

/// A widget for selecting colors from the database
class ColorSelector extends StatefulWidget {
  final String? selectedColorId;
  final Function(String? colorId) onColorSelected;
  final bool isRequired;
  final String? label;

  const ColorSelector({
    super.key,
    this.selectedColorId,
    required this.onColorSelected,
    this.isRequired = false,
    this.label,
  });

  @override
  State<ColorSelector> createState() => _ColorSelectorState();
}

class _ColorSelectorState extends State<ColorSelector> {
  List<ColorModel.Color> _availableColors = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    try {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });

      // Initialize default colors if needed
      final areInitialized = await DefaultColorsService.areDefaultColorsInitialized();
      if (!areInitialized) {
        await DefaultColorsService.initializeDefaultColors();
      }

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';

      // Load available colors for the user
      final colors = await DefaultColorsService.getAvailableColors(userId);
      
      setState(() {
        _availableColors = colors;
        _isLoading = false;
        _loadFailed = false;
      });

      // Find selected color if we have an ID
      if (widget.selectedColorId != null && _availableColors.isNotEmpty) {
        // Just verify the color exists in available colors
        _availableColors.firstWhere(
          (color) => color.id == widget.selectedColorId,
          orElse: () => _availableColors.first,
        );
      }

    } catch (e) {
      print('[ERROR] Failed to load colors: $e');
      setState(() {
        _isLoading = false;
        _loadFailed = true;
        // Fallback: provide a static color list if loading fails
        _availableColors = [
          ColorModel.Color(id: 'Black', name: 'Black', hexCode: '#000000', createdBy: 'SYSTEM_DEFAULT'),
          ColorModel.Color(id: 'White', name: 'White', hexCode: '#FFFFFF', createdBy: 'SYSTEM_DEFAULT'),
          ColorModel.Color(id: 'Red', name: 'Red', hexCode: '#FF0000', createdBy: 'SYSTEM_DEFAULT'),
          ColorModel.Color(id: 'Blue', name: 'Blue', hexCode: '#0000FF', createdBy: 'SYSTEM_DEFAULT'),
          ColorModel.Color(id: 'Green', name: 'Green', hexCode: '#00FF00', createdBy: 'SYSTEM_DEFAULT'),
          ColorModel.Color(id: 'Yellow', name: 'Yellow', hexCode: '#FFFF00', createdBy: 'SYSTEM_DEFAULT'),
        ];
      });
    }
  }

  Color _parseHexColor(String? hexCode) {
    if (hexCode == null || hexCode.isEmpty) return Colors.grey;
    
    try {
      // Remove # if present
      String colorCode = hexCode.replaceAll('#', '');
      
      // Add alpha if not present
      if (colorCode.length == 6) {
        colorCode = 'FF$colorCode';
      }
      
      return Color(int.parse(colorCode, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildColorIndicator(ColorModel.Color color, {double size = 24}) {
    final backgroundColor = _parseHexColor(color.hexCode);
    final needsBorder = backgroundColor.computeLuminance() > 0.8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: needsBorder || color.name == 'White'
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: print available color IDs and selected value
    print('[ColorSelector] available IDs: '
      + _availableColors.map((c) => c.id).join(', ')
      + ' | selected: '
      + (widget.selectedColorId ?? 'null'));

    String? dropdownValue = widget.selectedColorId;
    // If the selected value is not in the available list, set to null
    if (dropdownValue != null && !_availableColors.any((c) => c.id == dropdownValue)) {
      dropdownValue = null;
    }

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey(dropdownValue), // Ensure unique key for state
          value: dropdownValue,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: 'Select a color',
            errorText: widget.isRequired && dropdownValue == null 
                ? 'Color is required' 
                : null,
          ),
          items: _availableColors.map((color) {
            return DropdownMenuItem<String>(
              value: color.id,
              child: Row(
                children: [
                  _buildColorIndicator(color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      color.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (color.createdBy == 'SYSTEM_DEFAULT') ...[
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
          onChanged: (String? colorId) {
            widget.onColorSelected(colorId);
          },
          validator: widget.isRequired 
              ? (value) => value == null ? 'Please select a color' : null
              : null,
        ),
      ],
    );
  }
}

/// A simplified color display widget for showing selected colors
class ColorDisplay extends StatelessWidget {
  final String? colorId;
  final String? colorName;
  final String? hexCode;
  final double size;

  const ColorDisplay({
    super.key,
    this.colorId,
    this.colorName,
    this.hexCode,
    this.size = 20,
  });

  Color _parseHexColor(String? hexCode) {
    if (hexCode == null || hexCode.isEmpty) return Colors.grey;
    
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

  @override
  Widget build(BuildContext context) {
    if (colorId == null && colorName == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(
          Icons.help_outline,
          size: size * 0.6,
          color: Colors.grey.shade600,
        ),
      );
    }

    final backgroundColor = _parseHexColor(hexCode);
    final needsBorder = backgroundColor.computeLuminance() > 0.8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: needsBorder || colorName == 'White'
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
    );
  }
}

/// Widget for adding new colors
class AddColorDialog extends StatefulWidget {
  const AddColorDialog({super.key});

  @override
  State<AddColorDialog> createState() => _AddColorDialogState();
}

class _AddColorDialogState extends State<AddColorDialog> {
  final _nameController = TextEditingController();
  final _hexController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Color _parseHexColor(String hexCode) {
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

  Future<void> _createColor() async {
    if (_nameController.text.trim().isEmpty || _hexController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';

      final colorId = await DefaultColorsService.createColor(
        _nameController.text.trim(),
        _hexController.text.trim(),
        userId,
      );

      if (colorId != null && mounted) {
        Navigator.of(context).pop(colorId);
      }
    } catch (e) {
      print('[ERROR] Failed to create color: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Color Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hexController,
            decoration: InputDecoration(
              labelText: 'Hex Code (e.g., #FF0000)',
              border: const OutlineInputBorder(),
              suffixIcon: _hexController.text.isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _parseHexColor(_hexController.text),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    )
                  : null,
            ),
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createColor,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Color'),
        ),
      ],
    );
  }
}
