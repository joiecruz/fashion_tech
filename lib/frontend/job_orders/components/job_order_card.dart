import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/color_selector.dart';

class JobOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final int index;
  final Map<String, String> userNames;
  final Map<String, String> productNames;
  final Map<String, Map<String, dynamic>> productData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsDone;
  final String status;

  const JobOrderCard({
    super.key,
    required this.doc,
    required this.index,
    required this.userNames,
    required this.productNames,
    required this.productData,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkAsDone,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    // ERDv8 JobOrder fields
    final String jobOrderID = doc.id;
    final String jobOrderName = data['name'] ?? 'Unnamed Job Order';
    final String productID = data['productID'] ?? '';
    final int quantity = data['quantity'] ?? 0;
    final String customerName = data['customerName'] ?? '';
    final String status = data['status'] ?? 'Open';
    final Timestamp? dueDateTimestamp = data['dueDate'] as Timestamp?;
    final String assignedTo = data['assignedTo'] ?? '';
    final Timestamp? createdAtTimestamp = data['createdAt'] as Timestamp?;

    // Convert timestamps
    final DateTime? dueDate = dueDateTimestamp?.toDate();
    final DateTime? createdAt = createdAtTimestamp?.toDate();

    // Get related data
    final productInfo = productData[productID] ?? {};
    final List<dynamic> productVariants = productInfo['variants'] ?? [];
    final List<dynamic> productFabrics = productInfo['fabrics'] ?? [];

    // Try to find the matching variant for this job order
    Map<String, dynamic>? matchedVariant;
    if (data['variantID'] != null && data['variantID'].toString().isNotEmpty) {
      matchedVariant = productVariants.cast<Map<String, dynamic>>().firstWhere(
        (v) => v['variantID'] == data['variantID'],
        orElse: () => {},
      );
    }

    // Try to find the matching fabric for this job order
    Map<String, dynamic>? matchedFabric;
    if (data['fabricID'] != null && data['fabricID'].toString().isNotEmpty) {
      matchedFabric = productFabrics.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['fabricID'] == data['fabricID'],
        orElse: () => {},
      );
    }

    // Extract color, size, and fabric name
    final String variantColor = matchedVariant?['color'] ?? '';
    final String variantSize = matchedVariant?['size'] ?? '';
    final String fabricName = matchedFabric?['fabricName'] ?? '';

    // Check if overdue
    final bool isOverdue = dueDate != null &&
                          dueDate.isBefore(DateTime.now()) &&
                          status != 'Done';
    final int overdueDays = isOverdue ?
        DateTime.now().difference(dueDate).inDays : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: isOverdue ? Border.all(color: Colors.red.shade200, width: 1) : null,
      ),
      child: InkWell(
        onTap: () {
          print('Navigate to job order details: $jobOrderID');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with job order name, status, and quantity
              Row(
                children: [
                  // Job order icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[100]!, Colors.orange[200]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Job order name and product
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                jobOrderName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Quantity badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                productNames[productID] ?? 'Not linked to a product',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(status).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Compact info grid
              Row(
                children: [
                  // Customer & Assignment column
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Customer',
                          value: customerName.isNotEmpty ? customerName : 'No customer',
                          isCompact: true,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          icon: Icons.assignment_ind_outlined,
                          label: 'Assigned',
                          value: assignedTo.isNotEmpty ? userNames[assignedTo] ?? assignedTo : 'Unassigned',
                          isCompact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Dates column
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created',
                          value: createdAt != null ? _formatCompactDate(createdAt) : '-',
                          isCompact: true,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          icon: isOverdue ? Icons.warning_outlined : Icons.schedule_outlined,
                          label: 'Due Date',
                          value: dueDate != null ? _formatCompactDate(dueDate) : '-',
                          isCompact: true,
                          isUrgent: isOverdue,
                          urgentText: isOverdue ? '$overdueDays days overdue' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Category and upcycled tags (if applicable)
              if (productInfo['category'] != null || productInfo['isUpcycled'] == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (productInfo['category'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (productInfo['category'] as String).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (productInfo['isUpcycled'] == true) const SizedBox(width: 6),
                    ],
                    if (productInfo['isUpcycled'] == true) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'UPCYCLED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Color, size, and fabric info (if available)
              if (variantColor.isNotEmpty || variantSize.isNotEmpty || fabricName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (variantColor.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ColorDisplay(
                              colorId: variantColor, // This might be a colorID or legacy color name
                              colorName: variantColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              variantColor,
                              style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (variantSize.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Size: $variantSize',
                          style: TextStyle(fontSize: 10, color: Colors.purple[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (fabricName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Fabric: $fabricName',
                          style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Compact action buttons
              Row(
                children: [
                  // Edit button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Delete button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 14),
                      label: const Text('Delete', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Mark as Done / Completed indicator
                  if (status != 'Done')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMarkAsDone,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Mark as Done', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.orange[600]!;
      case 'In Progress':
        return Colors.orange[500]!;
      case 'Done':
        return Colors.green[600]!;
      default:
        return Colors.orange[400]!;
    }
  }

  // Helper method for compact info rows
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCompact = false,
    bool isUrgent = false,
    String? urgentText,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: isUrgent ? Colors.red[600] : Colors.grey[500],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? Colors.red[700] : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (urgentText != null) ...[
                Text(
                  urgentText,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Compact date formatting
  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '${weeks}w ago';
    } else {
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    }
  }
}
