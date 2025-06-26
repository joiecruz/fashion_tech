import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_fabric_modal.dart'; // Import the AddFabricModal widget
import 'dart:convert';

class FabricLogbookPage extends StatelessWidget {
  const FabricLogbookPage({super.key});

  bool _isBase64Image(String str) {
    return str.startsWith('data:image/') || (str.isNotEmpty && !str.startsWith('http'));
  }

  ImageProvider _getSwatchImageProvider(String swatchUrl) {
    if (_isBase64Image(swatchUrl)) {
      final base64Str = swatchUrl.startsWith('data:image/')
          ? swatchUrl.split(',').last
          : swatchUrl;
      return MemoryImage(base64Decode(base64Str));
    } else {
      return NetworkImage(swatchUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fabric Logbook')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fabrics')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading fabrics'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fabrics = snapshot.data!.docs;

          if (fabrics.isEmpty) {
            return const Center(child: Text('No fabrics added yet.'));
          }

          return ListView.builder(
            itemCount: fabrics.length,
            itemBuilder: (context, index) {
              final fabric = fabrics[index].data() as Map<String, dynamic>;
              final swatchUrl = fabric['swatchImageURL'] ?? '';
              final name = fabric['name'] ?? 'Unnamed Fabric';
              final type = fabric['type'] ?? '';
              final color = fabric['color'] ?? '';
              final quality = fabric['qualityGrade'] ?? '';
              final quantity = fabric['quantity'] ?? 0;
              final createdAt = fabric['createdAt'] != null
                  ? (fabric['createdAt'] as Timestamp).toDate()
                  : null;
              final reasons = fabric['reasons'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  type,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(child: Text('Edit')),
                              const PopupMenuItem(child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Swatch and Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: swatchUrl.isNotEmpty
                                ? Image(
                                    image: _getSwatchImageProvider(swatchUrl),
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.image_not_supported),
                                  )
                                : const Icon(Icons.image_not_supported),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Color: ',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      color,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (fabric['isUpcycled'] == true)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.recycling, color: Colors.green, size: 18),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Quality: ',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlueAccent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        quality.isNotEmpty ? quality : 'N/A',
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Qty: ',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '$quantity units',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(),
                      // Date and Reasons
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Created date',
                            child: Text(
                              createdAt != null
                                  ? "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}"
                                  : 'No date',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                          if (fabric['updatedAt'] != null &&
                              (fabric['createdAt'] == null ||
                               (fabric['updatedAt'] as Timestamp).toDate() != createdAt))
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                'Last Updated: ${_formatDate(fabric['updatedAt'] as Timestamp)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (reasons != null && reasons.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: const [
                            Icon(Icons.info, color: Colors.red, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Reasons: ',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(
                            reasons.toString(),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              margin: const EdgeInsets.only(top: 100), // Add space from the top (below notch/appbar)
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: AddFabricModal(),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Fabric',
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
