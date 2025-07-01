import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 🚨 TEMPORARY DEV IMPORTS - Remove before production
import 'package:fashion_tech/frontend/auth/login_page.dart';
import 'package:fashion_tech/frontend/auth/signup_page.dart';
import 'package:fashion_tech/frontend/profit/profit_checker.dart';
import 'package:fashion_tech/frontend/products/product_inventory_page.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Future<String> _getSupplierName(String supplierID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierID)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['supplierName'] ?? 'Unknown Supplier';
      }
      return '';
    } catch (e) {
      print('Error fetching supplier name: $e');
      return '';
    }
  }

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
              double totalYards = 0.0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final quantity = data['quantity'] ?? 0;
                  totalYards += (quantity as num).toDouble();
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
                            '${totalYards.toStringAsFixed(1)} yds',
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
                  ValueListenableBuilder<double>(
                    valueListenable: ProductInventoryPage.potentialValueNotifier,
                    builder: (context, projectedIncome, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Projected Income: ₱${projectedIncome.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProfitReportPage()),
                              );
                            },
                            child: const Text('View Report'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Fabric Insights Section (OUTSIDE Profit Checker) ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fabric Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  const Text(
                    'Current stock levels',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
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
                          final type = fabric['type'] ?? '';
                          final quantity = fabric['quantity'] ?? 0;
                          final supplierID = fabric['supplierID'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        color.isNotEmpty ? '$name ($color)' : name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      Text(
                                        'Type: ${type.isEmpty ? 'N/A' : type}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                      if (supplierID != null)
                                        FutureBuilder<String>(
                                          future: _getSupplierName(supplierID),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                              return Text(
                                                'Supplier: ${snapshot.data}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                    ],
                                  ),
                                ),
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // ===================================================================
          // 🚨 TEMPORARY DEV BUTTONS - REMOVE BEFORE PRODUCTION 🚨
          // ===================================================================
          // These buttons are for development navigation testing only.
          // TODO: Remove this entire section before deploying to production.
          // The actual navigation should be handled by proper authentication flow.
          Card(
            elevation: 2,
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '🚨 DEV MODE - Remove Before Production',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Temporary navigation buttons for testing authentication pages:',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Test Login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Test Signup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ], // End of main Column children
      ), // End of main Column
    ); // End of main Padding
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
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
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
  const SummaryTile({required this.label, required this.value});

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