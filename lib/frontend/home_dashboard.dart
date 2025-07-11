import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fashion_tech/frontend/transactions/transaction_dashboard_page.dart';
import 'package:fashion_tech/frontend/logs/productLogs.dart';
import 'package:fashion_tech/frontend/logs/jobOrderLogs.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}
class _HomeDashboardState extends State<HomeDashboard> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    } else {
      // Redirect to login if no user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<String> _getSupplierName(String supplierID) async {
    if (_currentUserId == null) return '';
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierID)
          .get();
      if (doc.exists) {
        final data = doc.data();
        // Only return supplier name if it belongs to current user
        if (data?['createdBy'] == _currentUserId) {
          return data?['supplierName'] ?? 'Unknown Supplier';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
  // Add this method inside _HomeDashboardState:
  Future<int> _getTotalStock() async {
    if (_currentUserId == null) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('createdBy', isEqualTo: _currentUserId)
          .where('deletedAt', isNull: true)
          .get();
      int totalStock = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // If product uses variants, sum their stock
        final productId = doc.id;
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('productVariants')
            .where('productID', isEqualTo: productId)
            .get();
        if (variantsSnapshot.docs.isNotEmpty) {
          for (var variantDoc in variantsSnapshot.docs) {
            final variantData = variantDoc.data();
            final qty = variantData['quantityInStock'];
            if (qty != null) {
              totalStock += (qty as num).toInt();
            }
          }
        } else {
          // Fallback to 'quantity' field if no variants
          final qty = data['quantity'];
          if (qty != null) {
            totalStock += (qty as num).toInt();
          }
        }
      }
      return totalStock;
    } catch (e) {
      return 0;
    }
  }

  Future<double> _getProjectedIncome() async {
    if (_currentUserId == null) return 0.0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('createdBy', isEqualTo: _currentUserId)
          .where('deletedAt', isNull: true)
          .get();
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final price = data['price'];
        final productId = doc.id;
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('productVariants')
            .where('productID', isEqualTo: productId)
            .get();
        if (variantsSnapshot.docs.isNotEmpty) {
          for (var variantDoc in variantsSnapshot.docs) {
            final variantData = variantDoc.data();
            final qty = variantData['quantityInStock'];
            if (qty != null && price != null) {
              total += (qty as num).toDouble() * (price as num).toDouble();
            }
          }
        } else {
          final qty = data['quantity'];
          if (qty != null && price != null) {
            total += (qty as num).toDouble() * (price as num).toDouble();
          }
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: 40, // Add bottom padding to ensure content is visible above main nav bar
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepPurple[100],
                      child: Icon(Icons.dashboard, color: Colors.deepPurple[700], size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Modularized sections:
              StatsRow(currentUserId: _currentUserId),
              const SizedBox(height: 24),
              LogsButtons(),
              const SizedBox(height: 18),
              RecentActivitySection(currentUserId: _currentUserId),
              const SizedBox(height: 18),
              ProfitCheckerSection(
                getTotalStock: _getTotalStock,
                getProjectedIncome: _getProjectedIncome,
              ),
              const SizedBox(height: 18),
              FabricInsightsSection(
                currentUserId: _currentUserId,
                getSupplierName: _getSupplierName,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Modularized Widgets ---

class StatsRow extends StatelessWidget {
  final String? currentUserId;
  const StatsRow({required this.currentUserId, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: currentUserId != null 
                ? FirebaseFirestore.instance
                    .collection('fabrics')
                    .where('createdBy', isEqualTo: currentUserId)
                    .where('deletedAt', isNull: true)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              double totalYards = 0.0;
              if (snapshot.hasData && !snapshot.hasError) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final quantity = data['quantity'];
                  if (quantity != null) {
                    totalYards += (quantity as num).toDouble();
                  }
                }
              }
              return modernStatCard(
                icon: Icons.checkroom,
                color: Colors.deepPurple,
                value: '${totalYards.toStringAsFixed(1)} yds',
                label: 'Fabric Units',
                gradient: LinearGradient(
                  colors: [Colors.deepPurple[100]!, Colors.deepPurple[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: currentUserId != null 
                ? FirebaseFirestore.instance
                    .collection('products')
                    .where('createdBy', isEqualTo: currentUserId)
                    .where('deletedAt', isNull: true)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              int totalProducts = (snapshot.hasData && !snapshot.hasError) ? snapshot.data!.docs.length : 0;
              return modernStatCard(
                icon: Icons.inventory_2,
                color: Colors.indigo,
                value: '$totalProducts items',
                label: 'Product Units',
                gradient: LinearGradient(
                  colors: [Colors.indigo[100]!, Colors.indigo[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LogsButtons extends StatelessWidget {
  const LogsButtons({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductLogsPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            elevation: 0,
          ),
          child: const Text('Product Logs'),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const JobOrderLogsPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            elevation: 0,
          ),
          child: const Text('Job Order Logs'),
        ),
      ],
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  final String? currentUserId;
  const RecentActivitySection({required this.currentUserId, super.key});
  @override
  Widget build(BuildContext context) {
    return modernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Recent Activity', Icons.timeline),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: currentUserId != null 
                ? FirebaseFirestore.instance
                    .collection('activity')
                    .where('createdBy', isEqualTo: currentUserId)
                    .limit(5)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recent activity.', style: TextStyle(color: Colors.black54)),
                );
              }
              final activities = snapshot.data?.docs ?? [];
              if (activities.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recent activity.', style: TextStyle(color: Colors.black54)),
                );
              }
              activities.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['timestamp'];
                final bTime = (b.data() as Map<String, dynamic>)['timestamp'];
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });
              return Column(
                children: activities.map((doc) {
                  return ActivityRow(
                    icon: _activityIcon(doc['type']),
                    color: Colors.deepPurple,
                    text: doc['description'] ?? '',
                    time: _timeAgo(doc['timestamp']),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfitCheckerSection extends StatelessWidget {
  final Future<int> Function() getTotalStock;
  final Future<double> Function() getProjectedIncome;
  const ProfitCheckerSection({required this.getTotalStock, required this.getProjectedIncome, super.key});
  @override
  Widget build(BuildContext context) {
    return modernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Profit Checker', Icons.attach_money),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: getTotalStock(),
            builder: (context, stockSnapshot) {
              return FutureBuilder<double>(
                future: getProjectedIncome(),
                builder: (context, incomeSnapshot) {
                  final projectedIncome = incomeSnapshot.data ?? 0.0;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Projected Income',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${projectedIncome.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'All Stocks',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stockSnapshot.connectionState == ConnectionState.waiting
                                  ? '...'
                                  : '${stockSnapshot.data ?? 0} items',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TransactionDashboardPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text('View'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class FabricInsightsSection extends StatelessWidget {
  final String? currentUserId;
  final Future<String> Function(String) getSupplierName;
  const FabricInsightsSection({required this.currentUserId, required this.getSupplierName, super.key});
  @override
  Widget build(BuildContext context) {
    return modernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Fabric Insights', Icons.insights),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: currentUserId != null 
                ? FirebaseFirestore.instance
                    .collection('fabrics')
                    .where('createdBy', isEqualTo: currentUserId)
                    .where('deletedAt', isNull: true)
                    .limit(3)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Start adding fabrics to see insights here.', style: TextStyle(color: Colors.black54)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No fabric data found.', style: TextStyle(color: Colors.black54)),
                );
              }
              final fabrics = snapshot.data!.docs.toList();
              fabrics.sort((a, b) {
                final aQty = (a.data() as Map<String, dynamic>)['quantity'] ?? 0;
                final bQty = (b.data() as Map<String, dynamic>)['quantity'] ?? 0;
                return (bQty as num).compareTo(aQty as num);
              });
              return Column(
                children: fabrics.map((doc) {
                  final fabric = doc.data() as Map<String, dynamic>;
                  final name = fabric['name'] ?? 'Unnamed';
                  final color = fabric['color'] ?? '';
                  final type = fabric['type'] ?? '';
                  final quantity = fabric['quantity'] ?? 0;
                  final quantityDouble = (quantity as num).toDouble();
                  final supplierID = fabric['supplierID'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.checkroom, color: Colors.pink[400], size: 26),
                        ),
                        const SizedBox(width: 14),
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
                                  future: getSupplierName(supplierID),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.pink[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${quantityDouble.toStringAsFixed(1)} yds',
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
    );
  }
}

// Helper widgets and functions moved to top-level for modular widgets
Widget modernStatCard({
  required IconData icon,
  required Color color,
  required String value,
  required String label,
  required Gradient gradient,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

Widget modernCard({required Widget child}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

Widget sectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: Colors.deepPurple, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ],
  );
}

/// Helper widget for activity row
class ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String time;

  const ActivityRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}

IconData _activityIcon(String? type) {
  switch (type) {
    case 'fabric':
      return Icons.checkroom;
    case 'product':
      return Icons.inventory_2;
    case 'order':
      return Icons.assignment_turned_in;
    default:
      return Icons.timeline;
  }
}

String _timeAgo(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final now = DateTime.now();
  final date = timestamp.toDate();
  final diff = now.difference(date);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}