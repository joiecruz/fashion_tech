import 'package:flutter/material.dart';
import '../models/form_models.dart';
import '../../../utils/color_utils.dart';

class VariantCard extends StatelessWidget {
  final FormProductVariant variant;
  final int index;
  final List<Map<String, dynamic>> userFabrics;
  final Map<String, double> fabricAllocated;
  final TextEditingController quantityController;
  final VoidCallback onRemove;
  final Function(int) onVariantChanged;
  final Function() onFabricYardageChanged;

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
    ];
    final bgColor = colors[index % colors.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Variant ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
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
          
          // Size and Quantity inputs (Color comes from fabrics)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: variant.size,
                  items: ['Small', 'Medium', 'Large', 'XL', 'XXL'].map((size) => 
                    DropdownMenuItem(value: size, child: Text(size))
                  ).toList(),
                  onChanged: (val) {
                    variant.size = val ?? 'Small';
                    onVariantChanged(index);
                  },
                  decoration: InputDecoration(
                    labelText: 'Size',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: variant.quantity == 0 ? '' : variant.quantity.toString(),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.number,
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
    int variantQty = variant.quantity;
    // Note: This would need access to all variants to calculate sumVariants
    // For now, we'll show individual progress
    double progress = globalQty > 0 ? (variantQty / globalQty).clamp(0.0, 1.0) : 0.0;
    bool isOverAllocated = variantQty > globalQty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverAllocated ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverAllocated ? Colors.red.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverAllocated ? Icons.warning_rounded : Icons.check_circle_rounded,
                size: 16,
                color: isOverAllocated ? Colors.red.shade600 : Colors.green.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Quantity Allocation',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOverAllocated ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${variantQty}/${globalQty}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOverAllocated ? Colors.red.shade700 : Colors.green.shade700,
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
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverAllocated ? Colors.red.shade400 : Colors.green.shade400,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOverAllocated 
                ? 'Exceeds global quantity'
                : 'Within allocation limits',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOverAllocated ? Colors.red.shade700 : Colors.green.shade700,
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
          child: Row(
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
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.number,
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
