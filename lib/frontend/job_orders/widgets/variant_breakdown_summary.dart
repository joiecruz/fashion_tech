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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Variant Breakdown Summary',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (variants.isNotEmpty) ...[
            // Horizontal scrollable variant cards
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: variants.asMap().entries.map((entry) {
                    int idx = entry.key;
                    FormProductVariant variant = entry.value;
                    return _buildVariantSummaryCard(variant, idx);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Summary stats with bar chart
            _buildQuantityBarChart(context),
            const SizedBox(height: 16),
            
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
                    '${variants.fold(0.0, (sum, v) => sum + v.fabrics.fold(0.0, (s, f) => s + f.yardsRequired)).toStringAsFixed(1)}',
                    Icons.straighten,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      int globalQty = int.tryParse(quantityController.text) ?? 0;
                      int sumVariants = variants.fold(0, (sum, v) => sum + v.quantity);
                      bool isBalanced = globalQty == sumVariants;
                      return _buildSummaryCard(
                        'Quantity Status',
                        isBalanced ? 'Balanced' : 'Unbalanced',
                        isBalanced ? Icons.check_circle : Icons.warning,
                        isBalanced ? Colors.green : Colors.red,
                      );
                    },
                  ),
                ],
              ),
            ),
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
      ),
    );
  }

  Widget _buildVariantSummaryCard(FormProductVariant variant, int index) {
    final variantColors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
    ];
    final cardColor = variantColors[index % variantColors.length];
    
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      width: 140,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variant ${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            variant.size,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (variant.fabrics.isNotEmpty) ...[
            Row(
              children: [
                ...(variant.fabrics.take(3).map((fabric) {
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
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  );
                }).toList()),
                if (variant.fabrics.length > 3) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '+${variant.fabrics.length - 3}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Text(
              'No fabrics',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${variant.quantity} unit${variant.quantity == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityBarChart(BuildContext context) {
    int globalQty = int.tryParse(quantityController.text) ?? 0;
    
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.purple.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'Quantity Allocation Chart',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $globalQty',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),
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
                      Text(
                        'Variant ${idx + 1} (${variant.size})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${variant.quantity} (${(percentage * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
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
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
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
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color.shade600,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
