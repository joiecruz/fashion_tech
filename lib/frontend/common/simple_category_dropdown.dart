import 'package:flutter/material.dart';
import '../../services/category_service.dart';

/// Simple, safe category dropdown that loads categories from database
class SimpleCategoryDropdown extends StatefulWidget {
  final String? selectedCategory;
  final Function(String?) onChanged;
  final bool isRequired;
  final FormFieldValidator<String>? validator;

  const SimpleCategoryDropdown({
    super.key,
    this.selectedCategory,
    required this.onChanged,
    this.isRequired = false,
    this.validator,
  });

  @override
  State<SimpleCategoryDropdown> createState() => _SimpleCategoryDropdownState();
}

class _SimpleCategoryDropdownState extends State<SimpleCategoryDropdown> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeFallbackCategories();
    _loadCategories();
  }

  void _initializeFallbackCategories() {
    // Start with fallback categories immediately (matching CategoryService defaults)
    _categories = [
      {'name': 'top', 'displayName': 'Top'},
      {'name': 'bottom', 'displayName': 'Bottom'},
      {'name': 'outerwear', 'displayName': 'Outerwear'},
      {'name': 'dress', 'displayName': 'Dress'},
      {'name': 'activewear', 'displayName': 'Activewear'},
      {'name': 'underwear', 'displayName': 'Underwear & Intimates'},
      {'name': 'sleepwear', 'displayName': 'Sleepwear'},
      {'name': 'swimwear', 'displayName': 'Swimwear'},
      {'name': 'footwear', 'displayName': 'Footwear'},
      {'name': 'accessories', 'displayName': 'Accessories'},
      {'name': 'formal', 'displayName': 'Formal Wear'},
      {'name': 'uncategorized', 'displayName': 'Uncategorized'},
    ];
    _isLoading = false;
  }

  Future<void> _loadCategories() async {
    try {
      // Initialize categories if needed
      final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
      
      if (!isInitialized) {
        await CategoryService.initializeDefaultCategories();
      }

      // Get categories from service
      final categories = await CategoryService.getAllProductCategories();
      
      if (mounted && categories.isNotEmpty) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      // Continue with fallback categories on error
      _initializeCategoriesInBackground();
    }
  }

  Future<void> _initializeCategoriesInBackground() async {
    try {
      await CategoryService.initializeDefaultCategories();
      final categories = await CategoryService.getAllProductCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      // Silent fail - continue with fallback categories
    }
  }

  Widget _buildCategoryIcon(String categoryName) {
    IconData iconData;
    Color iconColor;

    switch (categoryName.toLowerCase()) {
      case 'top':
        iconData = Icons.checkroom;
        iconColor = Colors.blue;
        break;
      case 'bottom':
        iconData = Icons.person;
        iconColor = Colors.green;
        break;
      case 'outerwear':
        iconData = Icons.ac_unit;
        iconColor = Colors.purple;
        break;
      case 'dress':
        iconData = Icons.woman;
        iconColor = Colors.pink;
        break;
      case 'activewear':
        iconData = Icons.sports;
        iconColor = Colors.red;
        break;
      case 'underwear':
        iconData = Icons.favorite;
        iconColor = Colors.deepPurple;
        break;
      case 'sleepwear':
        iconData = Icons.bedtime;
        iconColor = Colors.indigo;
        break;
      case 'swimwear':
        iconData = Icons.pool;
        iconColor = Colors.cyan;
        break;
      case 'footwear':
        iconData = Icons.directions_walk;
        iconColor = Colors.brown;
        break;
      case 'accessories':
        iconData = Icons.watch;
        iconColor = Colors.orange;
        break;
      case 'formal':
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'uncategorized':
      default:
        iconData = Icons.category;
        iconColor = Colors.grey;
        break;
    }

    return Icon(
      iconData,
      size: 18,
      color: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.selectedCategory == null) {
      return Container(
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
      );
    }

    // Ensure current selection is in the categories list if it exists
    List<Map<String, dynamic>> availableCategories = List.from(_categories);
    
    // If we have a selected category that's not in our list, add it temporarily
    if (widget.selectedCategory != null && 
        !availableCategories.any((cat) => cat['name'] == widget.selectedCategory)) {
      availableCategories.add({
        'name': widget.selectedCategory!,
        'displayName': widget.selectedCategory!.toUpperCase(),
      });
    }

    return DropdownButtonFormField<String>(
      value: widget.selectedCategory,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintText: 'Select a category',
      ),
      items: availableCategories.map((category) {
        final categoryName = category['name'] as String;
        final displayName = category['displayName'] as String? ?? categoryName.toUpperCase();
        
        return DropdownMenuItem<String>(
          value: categoryName,
          child: Row(
            children: [
              _buildCategoryIcon(categoryName),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      validator: widget.validator ?? (widget.isRequired 
          ? (value) => value == null || value.isEmpty ? 'Please select a category' : null
          : null),
      onChanged: (value) {
        widget.onChanged(value);
      },
    );
  }
}
