import 'package:flutter/material.dart';
import '../models/form_models.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/size_utils.dart';

// ===============================================================================
// VARIANT CARD CUSTOMIZATION GUIDE
// ===============================================================================
// 
// To modify the QUANTITY FIELD HEIGHT:
// 1. Search for "QUANTITY FIELD HEIGHT CONFIGURATION" in this file (around line 155)
// 2. Change the height value in the Container widget
// 3. Optionally adjust contentPadding for better visual balance
//
// Current quantity field height: 56px (matches size dropdown)
// ===============================================================================

class VariantCard extends StatelessWidget {
  final FormProductVariant variant;
  final int index;
  final List<Map<String, dynamic>> userFabrics;
  final Map<String, double> fabricAllocated;
  final TextEditingController quantityController;
  final VoidCallback onRemove;
  final Function(int) onVariantChanged;
  final Function() onFabricYardageChanged;
  final int sumVariants; // Sum of all variant quantities

  const VariantCard({
    Key? key,
    required this.variant,
    required this.index,
    required this.userFabrics,
    required this.fabricAllocated,
    required this.quantityController,
    required this.onRemove,
    required this.onVariantChanged,
    required this.onFabricYardageChanged,
    required this.sumVariants, // Required parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = [
      Color(0xFFF8FAFC), // Slate 50
      Color(0xFFF0FDF4), // Green 50
      Color(0xFFFEFBEA), // Amber 50
      Color(0xFFFAF5FF), // Violet 50
      Color(0xFFECFEFF), // Cyan 50
    ];
    final borderColors = [
      Color(0xFFE2E8F0), // Slate 200
      Color(0xFFBBF7D0), // Green 200
      Color(0xFFFDE68A), // Amber 200
      Color(0xFFDDD6FE), // Violet 200
      Color(0xFFA7F3D0), // Emerald 200
    ];
    final bgColor = colors[index % colors.length];
    final borderColor = borderColors[index % borderColors.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'Variant ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete, color: Colors.red.shade400),
                tooltip: 'Remove Variant',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Size and Quantity inputs with guaranteed identical heights
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: variant.size,
                  items: SizeUtils.buildSizeDropdownItems(
                    showDescriptions: false,
                    compact: true,
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return SizeUtils.buildConstrainedSizeSelectedItems(
                      context,
                      compact: true,
                      maxWidth: 120,
                    );
                  },
                  onChanged: (val) {
                    variant.size = val ?? SizeUtils.sizeOptions.first;
                    onVariantChanged(index);
                  },
                  decoration: InputDecoration(
                    labelText: 'Size',
                    labelStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    isDense: false,
                  ),
                  isDense: false,
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: variant.quantity == 0 ? '' : variant.quantity.toString(),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                    errorMaxLines: 2,
                    isDense: false,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val?.isEmpty ?? true) return 'Quantity required';
                    final trimmed = val!.trim();
                    if (trimmed.isEmpty) return 'Quantity cannot be empty';
                    // Check for non-numeric characters
                    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                      return 'Use numbers only';
                    }
                    final n = int.tryParse(trimmed);
                    if (n == null) return 'Enter whole number';
                    if (n <= 0) return 'Must be greater than 0';
                    if (n > 1000) return 'Too large (max: 1,000)';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (val) {
                    variant.quantity = int.tryParse(val) ?? 0;
                    onVariantChanged(index);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quantity Allocation Progress
          _buildQuantityAllocationProgress(),
          const SizedBox(height: 16),
          
          // Fabric colors display with enhanced design
          if (variant.fabrics.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fabric Colors',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...variant.fabrics.map((fabric) {
                        final fabricData = userFabrics.firstWhere(
                          (f) => f['id'] == fabric.fabricId,
                          orElse: () => {'color': '#FF0000', 'name': 'Unknown'},
                        );
                        final color = ColorUtils.parseColor(fabricData['color'] as String);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.grey.shade600 
                                        : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fabricData['name'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Fabrics section
          Row(
            children: [
              Text(
                'Fabrics',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: userFabrics.isEmpty ? null : () {
                  variant.fabrics.add(VariantFabric(
                    fabricId: userFabrics.first['id']!,
                    fabricName: userFabrics.first['name']!,
                    yardageUsed: 0,
                  ));
                  // Update variant color based on fabrics
                  variant.color = _getVariantColorFromFabrics();
                  onVariantChanged(index);
                },
                icon: Icon(Icons.add_circle_outline, size: 14),
                label: Text(
                  'Add Fabric',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(color: Colors.blue.shade300, width: 1),
                  backgroundColor: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Fabric list
          if (variant.fabrics.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                  const SizedBox(width: 12),
                  Text('No fabrics added yet', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            Column(
              children: variant.fabrics.asMap().entries.map((fabricEntry) {
                int fabricIndex = fabricEntry.key;
                VariantFabric fabric = fabricEntry.value;
                return _buildFabricRow(fabric, fabricIndex);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantityAllocationProgress() {
    int globalQty = int.tryParse(quantityController.text) ?? 0;
    int sumQty = sumVariants; // Use sum of all variants instead of individual
    bool isExact = sumQty == globalQty && globalQty > 0;
    bool isOver = sumQty > globalQty;
    double progress = globalQty > 0 ? (sumQty / globalQty).clamp(0.0, 1.0) : 0.0;

    Color barColor = isExact
        ? Colors.blue.shade400
        : isOver
            ? Colors.red.shade400
            : Colors.orange.shade400;
    Color bgColor = isExact
        ? Colors.blue.shade50
        : isOver
            ? Colors.red.shade50
            : Colors.orange.shade50;
    Color borderColor = isExact
        ? Colors.blue.shade200
        : isOver
            ? Colors.red.shade200
            : Colors.orange.shade200;
    Color textColor = isExact
        ? Colors.blue.shade700
        : isOver
            ? Colors.red.shade700
            : Colors.orange.shade700;
    IconData icon = isExact
        ? Icons.check_circle_rounded
        : isOver
            ? Icons.warning_rounded
            : Icons.info_outline_rounded;

    String statusText = isExact
        ? 'Perfect! All variants allocated.'
        : isOver
            ? 'Over-allocated by ${sumQty - globalQty}'
            : 'Unallocated: ${globalQty - sumQty}';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Total Variant Allocation',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '${sumQty} / ${globalQty}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine variant color from fabrics
  String _getVariantColorFromFabrics() {
    if (variant.fabrics.isEmpty) {
      return 'Mixed'; // Default when no fabrics
    }
    
    // Get the first fabric's color as the primary color
    final firstFabricData = userFabrics.firstWhere(
      (f) => f['id'] == variant.fabrics.first.fabricId,
      orElse: () => {'color': '#FF0000'},
    );
    
    final firstColor = ColorUtils.parseColor(firstFabricData['color'] as String);
    
    // Check if all fabrics are similar colors, otherwise return "Mixed"
    bool allSimilar = variant.fabrics.every((fabric) {
      final fabricData = userFabrics.firstWhere(
        (f) => f['id'] == fabric.fabricId,
        orElse: () => {'color': '#FF0000'},
      );
      final color = ColorUtils.parseColor(fabricData['color'] as String);
      
      // Simple color similarity check (you could make this more sophisticated)
      return (color.red - firstColor.red).abs() < 50 &&
             (color.green - firstColor.green).abs() < 50 &&
             (color.blue - firstColor.blue).abs() < 50;
    });
    
    if (allSimilar) {
      // Try to match with ColorUtils color names
      for (String colorName in ColorUtils.colorOptions) {
        final namedColor = ColorUtils.getColor(colorName);
        if ((namedColor.red - firstColor.red).abs() < 30 &&
            (namedColor.green - firstColor.green).abs() < 30 &&
            (namedColor.blue - firstColor.blue).abs() < 30) {
          return colorName;
        }
      }
      return 'Custom';
    }
    
    return 'Mixed';
  }

  Widget _buildFabricRow(VariantFabric fabric, int fabricIndex) {
    final fabricData = userFabrics.firstWhere(
      (f) => f['id'] == fabric.fabricId,
      orElse: () => {'color': '#FF0000', 'name': 'Unknown', 'quantity': 0},
    );
    final color = ColorUtils.parseColor(fabricData['color'] as String);
    final luminance = color.computeLuminance();
    final isLightColor = luminance > 0.5;
    
    final available = (fabricData['quantity'] ?? 0) as num;
    final allocated = fabricAllocated[fabric.fabricId] ?? 0;
    final overAllocated = allocated > available;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLightColor ? Colors.grey.shade600 : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: fabric.fabricId,
                    items: userFabrics.map((f) => DropdownMenuItem<String>(
                      value: f['id'] as String,
                      child: Text(
                        f['name'] as String, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13),
                      ),
                    )).toList(),
                    onChanged: (val) {
                      final selected = userFabrics.firstWhere((f) => f['id'] == val);
                      fabric.fabricId = val!;
                      fabric.fabricName = selected['name'] as String;
                      // Update variant color when fabric changes
                      variant.color = _getVariantColorFromFabrics();
                      onVariantChanged(index);
                      onFabricYardageChanged();
                    },
                    decoration: InputDecoration(
                      labelText: 'Fabric',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    isExpanded: true, // This prevents overflow
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: fabric.yardageUsed == 0 ? '' : fabric.yardageUsed.toString(),
                    decoration: InputDecoration(
                      labelText: 'Yards',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      errorMaxLines: 2,
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val?.isEmpty ?? true) return 'Yards required';
                      final trimmed = val!.trim();
                      if (trimmed.isEmpty) return 'Cannot be empty';
                      
                      // Check for invalid characters (allow decimals)
                      if (!RegExp(r'^\d*\.?\d*$').hasMatch(trimmed)) {
                        return 'Numbers only';
                      }
                      
                      final n = double.tryParse(trimmed);
                      if (n == null) return 'Enter valid number';
                      if (n <= 0) return 'Must be > 0';
                      if (n > 1000) return 'Too large (max: 1,000)';
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (val) {
                      fabric.yardageUsed = double.tryParse(val) ?? 0;
                      onVariantChanged(index);
                      onFabricYardageChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    variant.fabrics.removeAt(fabricIndex);
                    // Update variant color when fabric is removed
                    variant.color = _getVariantColorFromFabrics();
                    onVariantChanged(index);
                    onFabricYardageChanged();
                  },
                  icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                  tooltip: 'Remove Fabric',
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ),
        
        // Fabric Availability Tracker
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: overAllocated ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: overAllocated ? Colors.red.shade200 : Colors.green.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    overAllocated ? Icons.warning_rounded : Icons.inventory_rounded,
                    size: 16,
                    color: overAllocated ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fabric Availability',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: overAllocated ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: overAllocated ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${allocated.toStringAsFixed(1)}/${available.toStringAsFixed(1)} yds',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: overAllocated ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: available > 0 ? (allocated / available).clamp(0.0, 1.0) : 0.0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overAllocated ? Colors.red.shade400 : Colors.green.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                overAllocated
                    ? 'Over-allocated by ${(allocated - available).toStringAsFixed(1)} yards'
                    : '${(available - allocated).toStringAsFixed(1)} yards remaining',
                style: TextStyle(
                  fontSize: 11,
                  color: overAllocated ? Colors.red.shade600 : Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
