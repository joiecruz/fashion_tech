/// Service for handling fabric return operations
/// Manages fabric inventory when job orders are cancelled or deleted
/// 
/// Features:
/// - Automatic fabric return calculation
/// - User-controlled return amounts
/// - Inventory update with transaction safety
/// - Audit trail for fabric movements

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for fabric allocation data
class FabricAllocation {
  final String id;
  final String fabricId;
  final String fabricName;
  final double yardageUsed;
  final String color;
  final String size;
  final String? notes;

  const FabricAllocation({
    required this.id,
    required this.fabricId,
    required this.fabricName,
    required this.yardageUsed,
    required this.color,
    required this.size,
    this.notes,
  });

  factory FabricAllocation.fromMap(String id, Map<String, dynamic> data) {
    return FabricAllocation(
      id: id,
      fabricId: data['fabricID'] ?? '',
      fabricName: data['fabricName'] ?? 'Unknown Fabric',
      yardageUsed: (data['yardageUsed'] ?? 0).toDouble(),
      color: data['color'] ?? '',
      size: data['size'] ?? '',
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fabricID': fabricId,
      'fabricName': fabricName,
      'yardageUsed': yardageUsed,
      'color': color,
      'size': size,
      'notes': notes,
    };
  }

  /// Creates a unique key for grouping similar fabric allocations
  String get groupingKey => '${fabricId}_$color';
}

/// Model for fabric return transaction
class FabricReturn {
  final String fabricId;
  final String fabricName;
  final String color;
  final double returnAmount;
  final double originalAmount;
  final String reason;

  const FabricReturn({
    required this.fabricId,
    required this.fabricName,
    required this.color,
    required this.returnAmount,
    required this.originalAmount,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'fabricID': fabricId,
      'fabricName': fabricName,
      'color': color,
      'returnAmount': returnAmount,
      'originalAmount': originalAmount,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

/// Service for managing fabric returns
class FabricReturnService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches fabric allocations for a specific job order
  static Future<List<FabricAllocation>> getFabricAllocations(String jobOrderId) async {
    try {
      final snapshot = await _firestore
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: jobOrderId)
          .get();

      return snapshot.docs.map((doc) {
        return FabricAllocation.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch fabric allocations: $e');
    }
  }

  /// Groups fabric allocations by fabric and color for easier management
  static Map<String, List<FabricAllocation>> groupAllocations(
    List<FabricAllocation> allocations,
  ) {
    final Map<String, List<FabricAllocation>> grouped = {};
    
    for (final allocation in allocations) {
      final key = allocation.groupingKey;
      grouped[key] ??= [];
      grouped[key]!.add(allocation);
    }
    
    return grouped;
  }

  /// Calculates total fabric usage by type and color
  static Map<String, double> calculateTotalUsage(
    List<FabricAllocation> allocations,
  ) {
    final Map<String, double> totals = {};
    
    for (final allocation in allocations) {
      final key = '${allocation.fabricName}_${allocation.color}';
      totals[key] = (totals[key] ?? 0) + allocation.yardageUsed;
    }
    
    return totals;
  }

  /// Shows fabric return dialog and handles the return process
  static Future<Map<String, double>?> showFabricReturnDialog(
    BuildContext context,
    List<FabricAllocation> allocations, {
    String? title,
    String? description,
  }) async {
    if (allocations.isEmpty) return null;

    final Map<String, double> returnAmounts = {};
    final groupedAllocations = groupAllocations(allocations);

    // Initialize return amounts with full allocated amounts
    for (final entry in groupedAllocations.entries) {
      final totalUsage = entry.value.fold<double>(
        0,
        (sum, allocation) => sum + allocation.yardageUsed,
      );
      returnAmounts[entry.key] = totalUsage;
    }

    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title ?? 'Return Fabrics to Inventory'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description ?? 'Select fabrics to return to inventory:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groupedAllocations.length,
                    itemBuilder: (context, index) {
                      final entry = groupedAllocations.entries.elementAt(index);
                      final key = entry.key;
                      final allocationsGroup = entry.value;
                      final firstAllocation = allocationsGroup.first;
                      
                      final totalUsage = allocationsGroup.fold<double>(
                        0,
                        (sum, allocation) => sum + allocation.yardageUsed,
                      );
                      
                      return _buildFabricReturnCard(
                        fabricName: firstAllocation.fabricName,
                        color: firstAllocation.color,
                        totalUsage: totalUsage,
                        returnAmount: returnAmounts[key] ?? 0,
                        onReturnAmountChanged: (value) {
                          setState(() {
                            returnAmounts[key] = value;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Returned fabrics will be added back to inventory immediately.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, returnAmounts),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Return Fabrics'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a card for fabric return amount selection
  static Widget _buildFabricReturnCard({
    required String fabricName,
    required String color,
    required double totalUsage,
    required double returnAmount,
    required ValueChanged<double> onReturnAmountChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fabricName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (color.isNotEmpty)
                        Text(
                          'Color: $color',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Used: ${totalUsage.toStringAsFixed(1)} yards',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Return amount slider and input
            Row(
              children: [
                const Text('Return: '),
                Expanded(
                  child: Slider(
                    value: returnAmount,
                    min: 0,
                    max: totalUsage,
                    divisions: (totalUsage * 10).round().clamp(1, 1000),
                    label: '${returnAmount.toStringAsFixed(1)} yards',
                    onChanged: onReturnAmountChanged,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    key: ValueKey('return_$fabricName$color'),
                    initialValue: returnAmount.toStringAsFixed(1),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed >= 0 && parsed <= totalUsage) {
                        onReturnAmountChanged(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            // Quick action buttons
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => onReturnAmountChanged(0),
                  child: const Text('None'),
                ),
                TextButton(
                  onPressed: () => onReturnAmountChanged(totalUsage / 2),
                  child: const Text('Half'),
                ),
                TextButton(
                  onPressed: () => onReturnAmountChanged(totalUsage),
                  child: const Text('All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Processes fabric returns and updates inventory
  static Future<void> processFabricReturns(
    List<FabricAllocation> allocations,
    Map<String, double> returnAmounts,
    String reason,
  ) async {
    if (allocations.isEmpty || returnAmounts.isEmpty) return;

    final batch = _firestore.batch();
    final groupedAllocations = groupAllocations(allocations);
    final List<FabricReturn> returns = [];

    try {
      for (final entry in returnAmounts.entries) {
        final key = entry.key;
        final returnAmount = entry.value;
        
        if (returnAmount <= 0) continue;

        final allocationsGroup = groupedAllocations[key];
        if (allocationsGroup == null || allocationsGroup.isEmpty) continue;

        final firstAllocation = allocationsGroup.first;
        final totalOriginalAmount = allocationsGroup.fold<double>(
          0,
          (sum, allocation) => sum + allocation.yardageUsed,
        );

        // Update fabric inventory
        final fabricRef = _firestore.collection('fabrics').doc(firstAllocation.fabricId);
        batch.update(fabricRef, {
          'quantity': FieldValue.increment(returnAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create fabric return record
        final fabricReturn = FabricReturn(
          fabricId: firstAllocation.fabricId,
          fabricName: firstAllocation.fabricName,
          color: firstAllocation.color,
          returnAmount: returnAmount,
          originalAmount: totalOriginalAmount,
          reason: reason,
        );
        returns.add(fabricReturn);

        // Add to fabric return history
        final returnRef = _firestore.collection('fabricReturns').doc();
        batch.set(returnRef, fabricReturn.toMap());
      }

      await batch.commit();
      
      // Log the returns for audit purposes
      for (final fabricReturn in returns) {
        debugPrint(
          'Fabric returned: ${fabricReturn.fabricName} (${fabricReturn.color}) - '
          '${fabricReturn.returnAmount.toStringAsFixed(1)} yards. Reason: ${fabricReturn.reason}',
        );
      }
    } catch (e) {
      throw Exception('Failed to process fabric returns: $e');
    }
  }

  /// Gets fabric return history for a specific fabric
  static Future<List<Map<String, dynamic>>> getFabricReturnHistory(String fabricId) async {
    try {
      final snapshot = await _firestore
          .collection('fabricReturns')
          .where('fabricID', isEqualTo: fabricId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch fabric return history: $e');
    }
  }

  /// Validates if a fabric return amount is valid
  static bool isValidReturnAmount(double returnAmount, double totalUsage) {
    return returnAmount >= 0 && returnAmount <= totalUsage;
  }

  /// Calculates the total return value for display
  static double calculateTotalReturnValue(Map<String, double> returnAmounts) {
    return returnAmounts.values.fold(0, (sum, amount) => sum + amount);
  }
}

/// Exception class for fabric return errors
class FabricReturnException implements Exception {
  final String message;
  final dynamic originalError;

  const FabricReturnException(this.message, [this.originalError]);

  @override
  String toString() {
    return 'FabricReturnException: $message${originalError != null ? ' (Original: $originalError)' : ''}';
  }
}
