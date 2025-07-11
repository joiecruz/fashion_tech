import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fashion_tech/frontend/transactions/transaction_dashboard_page.dart';

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

class RecentActivitySection extends StatelessWidget {
  final String? currentUserId;
  const RecentActivitySection({required this.currentUserId, super.key});

  void _showLogsModal(BuildContext context, String? userId) {
    if (userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => LogsTabView(userId: userId, scrollController: scrollController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<_UnifiedLogEntry>>(
      future: _fetchRecentLogs(currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        return modernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  sectionTitle('Recent Activity', Icons.timeline),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showLogsModal(context, currentUserId),
                    icon: const Icon(Icons.open_in_new, size: 18, color: Colors.deepPurple),
                    label: const Text('View More', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('No recent activity.', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate how many logs can fit based on available height (min 8, but more if space allows)
                    int maxLogs = (constraints.maxHeight / 54).floor(); // 54px per row (approx)
                    maxLogs = maxLogs < 8 ? 8 : maxLogs;
                    return Column(
                      children: logs.take(maxLogs).map((log) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ActivityRow(
                          icon: log.icon,
                          color: log.color,
                          text: log.description,
                          time: log.timeAgo,
                        ),
                      )).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class LogsTabView extends StatefulWidget {
  final String userId;
  final ScrollController scrollController;
  const LogsTabView({required this.userId, required this.scrollController, super.key});

  @override
  State<LogsTabView> createState() => _LogsTabViewState();
}

class _LogsTabViewState extends State<LogsTabView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'Fabric Logs',
    'Product Logs',
    'Job Order Logs',
    'Transaction Logs',
    'Supplier Logs',
    'Customer Logs',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 18, right: 18, bottom: 0),
            child: Row(
              children: [
                const Text('All Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.deepPurple,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                LogsTable(logType: 'fabricLogs', userId: widget.userId, scrollController: widget.scrollController),
                LogsTable(logType: 'productLogs', userId: widget.userId, scrollController: widget.scrollController),
                LogsTable(logType: 'jobOrderLogs', userId: widget.userId, scrollController: widget.scrollController),
                LogsTable(logType: 'transactionLogs', userId: widget.userId, scrollController: widget.scrollController),
                LogsTable(logType: 'supplierLogs', userId: widget.userId, scrollController: widget.scrollController),
                LogsTable(logType: 'customerLogs', userId: widget.userId, scrollController: widget.scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LogsTable extends StatelessWidget {
  final String logType;
  final String userId;
  final ScrollController scrollController;
  const LogsTable({required this.logType, required this.userId, required this.scrollController, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection(logType)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No logs found.', style: TextStyle(color: Colors.black54)),
              ],
            ),
          );
        }
        // Table columns based on logType
        List<DataColumn> columns = [
          const DataColumn(label: Text('Date')),
          const DataColumn(label: Text('Remarks')),
        ];
        if (logType == 'productLogs' || logType == 'jobOrderLogs') {
          columns.add(const DataColumn(label: Text('Change Type')));
          columns.add(const DataColumn(label: Text('Qty')));
        }
        if (logType == 'productLogs') {
          columns.add(const DataColumn(label: Text('Supplier ID')));
        }
        if (logType == 'fabricLogs' || logType == 'supplierLogs') {
          columns.add(const DataColumn(label: Text('Supplier ID')));
        }
        if (logType == 'customerLogs') {
          columns.add(const DataColumn(label: Text('Customer ID')));
        }
        return Scrollbar(
          controller: scrollController,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns,
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['createdAt'] as Timestamp?)?.toDate();
                List<DataCell> cells = [
                  DataCell(Text(date != null ? _formatTimeAgo(date, DateTime.now()) : '')),
                  DataCell(Text(data['remarks']?.toString() ?? '')),
                ];
                if (logType == 'productLogs' || logType == 'jobOrderLogs') {
                  cells.add(DataCell(Text(data['changeType']?.toString() ?? '')));
                  cells.add(DataCell(Text(data['quantityChanged']?.toString() ?? '')));
                }
                if (logType == 'productLogs') {
                  cells.add(DataCell(Text(data['supplierID']?.toString() ?? '')));
                }
                if (logType == 'fabricLogs' || logType == 'supplierLogs') {
                  cells.add(DataCell(Text(data['supplierID']?.toString() ?? '')));
                }
                if (logType == 'customerLogs') {
                  cells.add(DataCell(Text(data['customerID']?.toString() ?? '')));
                }
                return DataRow(cells: cells);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// Remove duplicate and unused imports
// import 'package:fashion_tech/frontend/logs/productLogs.dart';
// import 'package:fashion_tech/frontend/logs/jobOrderLogs.dart';

// Move _UnifiedLogEntry, _fetchRecentLogs, and _formatTimeAgo to top-level
class _UnifiedLogEntry {
  final String description;
  final DateTime? date;
  final IconData icon;
  final Color color;
  final String timeAgo;
  _UnifiedLogEntry({
    required this.description,
    required this.date,
    required this.icon,
    required this.color,
    required this.timeAgo,
  });
}

Future<List<_UnifiedLogEntry>> _fetchRecentLogs(String userId) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  List<_UnifiedLogEntry> allLogs = [];
  // Fabric Logs
  final fabricLogs = await firestore
      .collection('fabricLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(fabricLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Fabric: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.checkroom,
      color: Colors.pink,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  // Product Logs
  final productLogs = await firestore
      .collection('productLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(productLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Product: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.inventory_2,
      color: Colors.indigo,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  // Job Order Logs
  final jobOrderLogs = await firestore
      .collection('jobOrderLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(jobOrderLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Job Order: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.assignment_turned_in,
      color: Colors.deepPurple,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  // Transaction Logs
  final transactionLogs = await firestore
      .collection('transactionLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(transactionLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Transaction: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.swap_horiz,
      color: Colors.green,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  // Customer Logs
  final customerLogs = await firestore
      .collection('customerLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(customerLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Customer: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.person,
      color: Colors.teal,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  // Supplier Logs
  final supplierLogs = await firestore
      .collection('supplierLogs')
      .where('createdBy', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  allLogs.addAll(supplierLogs.docs.map((doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    return _UnifiedLogEntry(
      description: 'Supplier: ${data['remarks'] ?? ''}',
      date: date,
      icon: Icons.local_shipping,
      color: Colors.orange,
      timeAgo: _formatTimeAgo(date, now),
    );
  }));
  allLogs.sort((a, b) {
    if (a.date == null && b.date == null) return 0;
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return b.date!.compareTo(a.date!);
  });
  return allLogs;
}

String _formatTimeAgo(DateTime? date, DateTime now) {
  if (date == null) return '';
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

// Remove duplicate widget/function definitions for modernStatCard, modernCard, sectionTitle, ActivityRow, _activityIcon, _timeAgo

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