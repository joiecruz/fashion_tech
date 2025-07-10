import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/color_selector.dart';
import '../job_order_detail_page.dart';

class JobOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final int index;
  final Map<String, String> userNames;
  final Map<String, String> productNames;
  final Map<String, Map<String, dynamic>> productData;
  final Map<String, String> categoryNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsDone;
  final VoidCallback? onUpdateStatus; // New callback for status updates
  final String status;

  const JobOrderCard({
    super.key,
    required this.doc,
    required this.index,
    required this.userNames,
    required this.productNames,
    required this.productData,
    required this.categoryNames,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkAsDone,
    this.onUpdateStatus,
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
    
    // Fetch variant data on-demand if needed for display (no longer cached)
    Map<String, dynamic>? matchedVariant;
    if (data['variantID'] != null && data['variantID'].toString().isNotEmpty) {
      // For now, we'll show the variant info from the job order data itself
      // since variants are no longer pre-cached to avoid bidirectional references
      matchedVariant = {
        'variantID': data['variantID'],
        'color': data['color'] ?? '',  // Job order stores its own variant info
        'size': data['size'] ?? '',    // Job order stores its own variant info
      };
    }

    // Try to find the matching fabric for this job order
    Map<String, dynamic>? matchedFabric;
    if (data['fabricID'] != null && data['fabricID'].toString().isNotEmpty) {
      // For now, we'll show the fabric info from the job order data itself
      // since fabrics are linked via job orders in ERDv9, not products
      matchedFabric = {
        'fabricID': data['fabricID'],
        'fabricName': data['fabricName'] ?? '',  // Job order may store fabric info
      };
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobOrderDetailPage(
                jobOrderId: jobOrderID,
                initialData: data,
              ),
            ),
          );
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
              if (productInfo['categoryName'] != null || productInfo['isUpcycled'] == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (productInfo['categoryName'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue[200]!, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category, size: 10, color: Colors.blue[700]),
                            const SizedBox(width: 3),
                            Text(
                              productInfo['categoryName'] as String,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
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

              // Special Instructions section (always show)
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Special Instructions',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (data['specialInstructions'] != null && data['specialInstructions'].toString().trim().isNotEmpty)
                                ? data['specialInstructions'].toString()
                                : (data['notes'] != null && data['notes'].toString().trim().isNotEmpty)
                                    ? data['notes'].toString()
                                    : 'No special instructions',
                            style: TextStyle(
                              fontSize: 11,
                              color: ((data['specialInstructions'] != null && data['specialInstructions'].toString().trim().isNotEmpty) ||
                                     (data['notes'] != null && data['notes'].toString().trim().isNotEmpty))
                                  ? Colors.grey[700]
                                  : Colors.grey[500],
                              fontStyle: ((data['specialInstructions'] != null && data['specialInstructions'].toString().trim().isNotEmpty) ||
                                         (data['notes'] != null && data['notes'].toString().trim().isNotEmpty))
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Cancel button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.cancel, size: 14),
                      label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Dynamic Status Button
                  _buildStatusButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton() {
    switch (status) {
      case 'Open':
        return Expanded(
          child: ElevatedButton.icon(
            onPressed: onUpdateStatus,
            icon: const Icon(Icons.play_arrow, size: 14),
            label: const Text('Start Work', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        );
      case 'In Progress':
        return Expanded(
          child: ElevatedButton.icon(
            onPressed: onMarkAsDone,
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Done', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        );
      case 'Done':
        return Expanded(
          child: ElevatedButton.icon(
            onPressed: onUpdateStatus,
            icon: const Icon(Icons.archive, size: 14),
            label: const Text('Archive', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        );
      case 'Archived':
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.archive, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Archived',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      case 'Cancelled':
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, size: 14, color: Colors.red[600]),
                const SizedBox(width: 4),
                Text(
                  'Cancelled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return Expanded(
          child: ElevatedButton.icon(
            onPressed: onMarkAsDone,
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Done', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue[600]!;  // Blue for new/open items
      case 'In Progress':
        return Colors.orange[600]!;  // Orange for work in progress
      case 'Done':
        return Colors.green[600]!;  // Green for completed
      case 'Archived':
        return Colors.grey[600]!;  // Grey for archived
      case 'Cancelled':
        return Colors.red[600]!;  // Red for cancelled
      default:
        return Colors.indigo[400]!;  // Indigo for unknown status
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

  // Improved date formatting with better readability
  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    final isFuture = date.isAfter(now);

    if (difference == 0 && !isFuture) {
      return 'Today';
    } else if (difference == 1 && !isFuture) {
      return 'Yesterday';
    } else if (difference == -1 && isFuture) {
      return 'Tomorrow';
    } else if (isFuture && difference.abs() < 7) {
      return 'in ${difference.abs()}d';
    } else if (difference < 7 && !isFuture) {
      return '${difference}d ago';
    } else if (difference < 30 && !isFuture) {
      final weeks = (difference / 7).floor();
      return '${weeks}w ago';
    } else if (isFuture && difference.abs() < 30) {
      final weeks = (difference.abs() / 7).floor();
      return 'in ${weeks}w';
    } else {
      // Use more readable format: Jan 15, '24
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, \'${date.year.toString().substring(2)}';
    }
  }
}
