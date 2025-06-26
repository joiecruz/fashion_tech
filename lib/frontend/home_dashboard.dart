import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fabric_logbook_page.dart';


class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome back!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // --- Overall Inventory Card ---
          // Total Fabric Units is calculated from Firestore.
          // Total Product Units is HARDCODED and should be replaced with Firestore data.
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('fabrics').snapshots(),
            builder: (context, snapshot) {
              int totalYards = 0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalYards += (data['quantity'] ?? 0) as int;
                }
              }
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.checkroom, size: 32, color: Colors.deepPurple),
                          const SizedBox(height: 8),
                          Text(
                            '${totalYards.toString()} yds',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total Fabric Units',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                      // TODO: Replace this HARDCODED value with Firestore query for products collection
                      Column(
                        children: [
                          const Icon(Icons.inventory_2, size: 32, color: Colors.deepPurple),
                          const SizedBox(height: 8),
                          const Text(
                            '387 items', // HARDCODED: Replace with Firestore data
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total Product Units',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- Recent Activity (Full Width, Responsive) ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activity')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              final activities = snapshot.data?.docs ?? [];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Expands a divider to the width of the card minus padding
                          return Container(
                            width: constraints.maxWidth,
                            height: 1,
                            color: Colors.grey[300],
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          );
                        },
                      ),
                      const Text(
                        'Latest system updates',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      if (activities.isEmpty)
                        const Text('No recent activity.'),
                      for (var doc in activities)
                        _ActivityRow(
                          icon: _activityIcon(doc['type']),
                          color: Colors.deepPurple,
                          text: doc['description'] ?? '',
                          time: _timeAgo(doc['timestamp']),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- Profit Checker (Full Width, Responsive) ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profit Checker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: constraints.maxWidth,
                        height: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      );
                    },
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Estimated Profit: ₱4,800'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to Sell or Detailed Report
                        },
                        child: const Text('View Report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Fabric List Section (Fabric Insights)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fabric Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FabricLogbookPage()),
                  );
                },
                child: const Text('View Fabric Logbook'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Current stock levels',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('fabrics')
                    .orderBy('quantity', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No fabric data found.'));
                  }
                  final fabrics = snapshot.data!.docs;
                  return Column(
                    children: fabrics.map((doc) {
                      final fabric = doc.data() as Map<String, dynamic>;
                      final name = fabric['name'] ?? 'Unnamed';
                      final color = fabric['color'] ?? '';
                      final minOrder = fabric['minOrder'] ?? '';
                      final quantity = fabric['quantity'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            // Name and min order
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    color.isNotEmpty ? '$name ($color)' : name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Min Order: ${minOrder.toString()} yds',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.pink[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$quantity yds',
                                style: const TextStyle(
                                  color: Colors.pink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Helper widget for activity row
class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String time;

  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.time,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Helper to pick icon based on activity type
IconData _activityIcon(String? type) {
  switch (type) {
    case 'order':
      return Icons.access_time;
    case 'fabric':
      return Icons.checkroom;
    case 'product':
      return Icons.inventory_2;
    case 'supplier':
      return Icons.local_shipping;
    default:
      return Icons.info_outline;
  }
}

/// Helper to format time ago
String _timeAgo(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final now = DateTime.now();
  final date = timestamp.toDate();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} minutes ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} hours ago';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else {
    return '${diff.inDays} days ago';
  }
}

class SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const SummaryTile({required this.label, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label),
      ],
    );
  }
}