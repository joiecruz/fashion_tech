import 'package:flutter/material.dart';
import '../models/form_models.dart';

class VariantBreakdownSummary extends StatelessWidget {
  final List<FormProductVariant> variants;
  final List<Map<String, dynamic>> userFabrics;
  final TextEditingController quantityController;
  final Function(String) parseColor;

  const VariantBreakdownSummary({
    Key? key,
    required this.variants,
    required this.userFabrics,
    required this.quantityController,
    required this.parseColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (variants.isNotEmpty) ...[
            // Summary stats cards
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Total Variants',
                    '${variants.length}',
                    Icons.category,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Fabrics',
                    '${variants.fold(0, (sum, v) => sum + v.fabrics.length)}',
                    Icons.palette,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Yards',
                    '${variants.fold(0.0, (sum, v) => sum + v.fabrics.fold(0.0, (s, f) => s + f.yardageUsed)).toStringAsFixed(1)}',
                    Icons.straighten,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      int globalQty = int.tryParse(quantityController.text) ?? 0;
                      int sumVariants = variants.fold(0, (sum, v) => sum + v.quantity);
                      bool isBalanced = globalQty == sumVariants && globalQty > 0;
                      bool isOver = sumVariants > globalQty;
                      
                      String statusText;
                      IconData statusIcon;
                      MaterialColor statusColor;
                      
                      if (globalQty == 0) {
                        statusText = 'Set Total Qty';
                        statusIcon = Icons.edit;
                        statusColor = Colors.grey;
                      } else if (isBalanced) {
                        statusText = 'Balanced ✓';
                        statusIcon = Icons.check_circle;
                        statusColor = Colors.green;
                      } else if (isOver) {
                        statusText = 'Over by ${sumVariants - globalQty}';
                        statusIcon = Icons.warning;
                        statusColor = Colors.red;
                      } else {
                        statusText = 'Under by ${globalQty - sumVariants}';
                        statusIcon = Icons.info;
                        statusColor = Colors.orange;
                      }
                      
                      return _buildSummaryCard(
                        'Allocation',
                        statusText,
                        statusIcon,
                        statusColor,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Summary stats with bar chart
            _buildQuantityBarChart(context),
            const SizedBox(height: 16),
            
            // Horizontal scrollable variant cards
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: variants.asMap().entries.map((entry) {
                      int idx = entry.key;
                      FormProductVariant variant = entry.value;
                      return _buildVariantSummaryCard(variant, idx);
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No variants to summarize',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
  }

  Widget _buildVariantSummaryCard(FormProductVariant variant, int index) {
    final variantColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final baseColor = variantColors[index % variantColors.length];
    
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.shade200),
        boxShadow: [
          BoxShadow(
            color: baseColor.shade100.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with variant number and size
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: baseColor.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'V${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: baseColor.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.checkroom,
                  size: 14,
                  color: baseColor.shade400,
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Size
            Text(
              variant.size,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Fabric colors
            if (variant.fabrics.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.palette,
                    size: 11,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...(variant.fabrics.take(4).map((fabric) {
                            final fabricData = userFabrics.firstWhere(
                              (f) => f['id'] == fabric.fabricId,
                              orElse: () => {'color': '#FF0000'},
                            );
                            final color = parseColor(fabricData['color'] as String);
                            return Container(
                              margin: const EdgeInsets.only(right: 2),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 1,
                                    offset: const Offset(0, 0.5),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                          if (variant.fabrics.length > 4) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '+${variant.fabrics.length - 4}',
                                  style: TextStyle(
                                    fontSize: 6,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 11,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'No fabrics',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            
            // Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: baseColor.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 10,
                    color: baseColor.shade600,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${variant.quantity}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: baseColor.shade700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    variant.quantity == 1 ? 'unit' : 'units',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityBarChart(BuildContext context) {
    int globalQty = int.tryParse(quantityController.text) ?? 0;
    int sumVariants = variants.fold(0, (sum, v) => sum + v.quantity);
    
    if (globalQty == 0 || variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Set total quantity to view allocation chart',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    bool isOverAllocated = sumVariants > globalQty;
    bool isUnderAllocated = sumVariants < globalQty;
    bool isBalanced = sumVariants == globalQty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverAllocated ? Colors.red.shade200 : 
                 isBalanced ? Colors.green.shade200 : Colors.orange.shade200,
          width: isBalanced ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverAllocated ? Icons.warning : isBalanced ? Icons.check_circle : Icons.info,
                color: isOverAllocated ? Colors.red.shade600 : 
                       isBalanced ? Colors.green.shade600 : Colors.orange.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quantity Allocation Chart',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isOverAllocated ? Colors.red.shade50 : 
                         isBalanced ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOverAllocated ? Colors.red.shade200 : 
                           isBalanced ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  '$sumVariants/$globalQty',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOverAllocated ? Colors.red.shade700 : 
                           isBalanced ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (isOverAllocated) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Over-allocated by ${sumVariants - globalQty} units. Please reduce variant quantities.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isUnderAllocated) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Under-allocated by ${globalQty - sumVariants} units. Consider adding more variants.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perfect allocation! All units are distributed across variants.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...variants.asMap().entries.map((entry) {
            int idx = entry.key;
            FormProductVariant variant = entry.value;
            double percentage = globalQty > 0 ? (variant.quantity / globalQty) : 0;
            
            final barColors = [
              Colors.blue.shade400,
              Colors.green.shade400,
              Colors.orange.shade400,
              Colors.purple.shade400,
              Colors.teal.shade400,
            ];
            final barColor = barColors[idx % barColors.length];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Variant ${idx + 1} (${variant.size})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${variant.quantity} (${(percentage * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: percentage > 1.0 ? Colors.red.shade700 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage > 1.0 ? Colors.red.shade400 : barColor,
                      ),
                    ),
                  ),
                  if (percentage > 1.0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Exceeds allocation',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      width: 120, // Fixed width to prevent overflow
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color.shade600,
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
