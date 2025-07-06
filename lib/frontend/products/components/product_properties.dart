import 'package:flutter/material.dart';

class ProductProperties extends StatelessWidget {
  final bool isUpcycled;
  final bool isMade;
  final Function(bool) onUpcycledChanged;
  final Function(bool) onMadeChanged;

  const ProductProperties({
    super.key,
    required this.isUpcycled,
    required this.isMade,
    required this.onUpcycledChanged,
    required this.onMadeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Properties',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            // Upcycled Switch
            Row(
              children: [
                Icon(
                  Icons.recycling,
                  color: Colors.green[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcycled Product',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Made from recycled materials',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isUpcycled,
                  onChanged: onUpcycledChanged,
                  activeColor: Colors.green[600],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Made Switch
            Row(
              children: [
                Icon(
                  Icons.handyman,
                  color: Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Made Product',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Product is ready for sale',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isMade,
                  onChanged: onMadeChanged,
                  activeColor: Colors.blue[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
