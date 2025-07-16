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
        if (data?['createdBy'] == _currentUserId) {
          return data?['supplierName'] ?? 'Unknown Supplier';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

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
            bottom: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const SizedBox.shrink();
    }
    return modernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Recent Activity', Icons.timeline),
          const SizedBox(height: 8),
          _LogTypeList(
            title: 'Product Logs',
            icon: Icons.inventory_2,
            color: Colors.indigo,
            collection: 'products',
            userId: currentUserId!,
          ),
          _LogTypeList(
            title: 'Fabric Logs',
            icon: Icons.checkroom,
            color: Colors.pink,
            collection: 'fabrics',
            userId: currentUserId!,
          ),
          _LogTypeList(
            title: 'Job Order Logs',
            icon: Icons.assignment_turned_in,
            color: Colors.deepPurple,
            collection: 'jobOrders',
            userId: currentUserId!,
          ),
          _LogTypeList(
            title: 'Supplier Logs',
            icon: Icons.local_shipping,
            color: Colors.orange,
            collection: 'suppliers',
            userId: currentUserId!,
          ),
          _LogTypeList(
            title: 'Customer Logs',
            icon: Icons.person,
            color: Colors.teal,
            collection: 'customers',
            userId: currentUserId!,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) => LogsTabView(
                      userId: currentUserId!,
                      scrollController: scrollController,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18, color: Colors.deepPurple),
              label: const Text(
                'View More',
                style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTypeList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String collection;
  final String userId;

  const _LogTypeList({
    required this.title,
    required this.icon,
    required this.color,
    required this.collection,
    required this.userId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String orderByField = collection == 'products' ? 'updatedAt' : 'createdAt';

return FutureBuilder<QuerySnapshot>(
  future: collection == 'products'
      ? FirebaseFirestore.instance
          .collection(collection)
          .where('createdBy', isEqualTo: userId)
          .where('deletedAt', isNull: true)
          .orderBy(orderByField, descending: true)
          .limit(1)
          .get()
      : FirebaseFirestore.instance
          .collection(collection)
          .where('createdBy', isEqualTo: userId)
          .orderBy(orderByField, descending: true)
          .limit(1)
          .get(),

          
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text('$title: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('No recent logs.', style: TextStyle(color: Colors.black54)),
              ],
            ),
          );
        }
        // Show name for all collections (products, suppliers, customers, etc.)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text('$title:', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
                print('Product data: $data');
              String name = data['name'] ?? data['supplierName'] ?? data['fullName'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            
            const SizedBox(height: 6),
          ],
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
    'Supplier Logs',
    'Customer Logs',
    'Product Logs',
    'Job Order Logs',
  ];

  final List<String> _collections = [
    'fabrics',
    'suppliers',
    'customers',
    'products',
    'jobOrders',
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
              children: List.generate(_collections.length, (i) {
                return LogsTable(
                  logType: _collections[i],
                  userId: widget.userId,
                  scrollController: widget.scrollController,
                );
              }),
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
  const LogsTable({
    required this.logType,
    required this.userId,
    required this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String userField = 'createdBy';
    String orderByField = 'createdAt';
    if (logType == 'salesLog') {
      userField = 'soldBy';
      orderByField = 'dateSold';
    } else if (logType == 'products') {
      orderByField = 'updatedAt';
    }

    final query = (logType == 'products')
        ? FirebaseFirestore.instance
            .collection(logType)
            .where(userField, isEqualTo: userId)
            .where('deletedAt', isNull: true)
            .orderBy(orderByField, descending: true)
            .limit(50)
        : FirebaseFirestore.instance
            .collection(logType)
            .where(userField, isEqualTo: userId)
            .orderBy(orderByField, descending: true)
            .limit(50);

    return FutureBuilder<QuerySnapshot>(
      future: query.get(),
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

        List<DataColumn> columns = [
          const DataColumn(label: Text('Date')),
        ];
        if (logType == 'fabrics') {
          columns.addAll([
            const DataColumn(label: Text('Name')),
            const DataColumn(label: Text('Type')),
            const DataColumn(label: Text('Color')),
            const DataColumn(label: Text('Quantity')),
          ]);
        } else if (logType == 'suppliers') {
          columns.addAll([
            const DataColumn(label: Text('Supplier Name')),
            const DataColumn(label: Text('Contact')),
          ]);
        } else if (logType == 'customers') {
          columns.addAll([
            const DataColumn(label: Text('Customer Name')),
            const DataColumn(label: Text('Contact')),
          ]);
        } else if (logType == 'products') {
          columns.addAll([
            const DataColumn(label: Text('Product Name')),
            const DataColumn(label: Text('Category')),
            const DataColumn(label: Text('Price')),
            const DataColumn(label: Text('Stock')),
            const DataColumn(label: Text('Supplier')),
            const DataColumn(label: Text('Updated At')),
          ]);
        } else if (logType == 'jobOrders') {
          columns.addAll([
            const DataColumn(label: Text('Job Name')),
            const DataColumn(label: Text('Status')),
          ]);
        } else {
          columns.add(const DataColumn(label: Text('Remarks')));
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
                DateTime? date;
                if (logType == 'salesLog') {
                  date = (data['dateSold'] as Timestamp?)?.toDate();
                } else if (logType == 'products') {
                  date = (data['updatedAt'] is Timestamp)
                      ? (data['updatedAt'] as Timestamp).toDate()
                      : null;
                } else {
                  date = (data['createdAt'] as Timestamp?)?.toDate();
                }
                List<DataCell> cells = [
                  DataCell(Text(date != null ? _formatTimeAgo(date, DateTime.now()) : '')),
                ];
                if (logType == 'fabrics') {
                  cells.addAll([
                    DataCell(Text(data['name']?.toString() ?? '')),
                    DataCell(Text(data['type']?.toString() ?? '')),
                    DataCell(Text(data['color']?.toString() ?? '')),
                    DataCell(Text(data['quantity']?.toString() ?? '')),
                  ]);
                } else if (logType == 'suppliers') {
                  cells.addAll([
                    DataCell(Text(data['supplierName']?.toString() ?? '')),
                    DataCell(Text(data['contactNum']?.toString() ?? '')),
                  ]);
                } else if (logType == 'customers') {
                  cells.addAll([
                    DataCell(Text(data['fullName']?.toString() ?? '')),
                    DataCell(Text(data['contactNum']?.toString() ?? '')),
                  ]);
                } else if (logType == 'products') {
                  cells.addAll([
                    DataCell(Text(data['name']?.toString() ?? '')),
                    DataCell(Text(data['category']?.toString() ?? data['categoryID']?.toString() ?? '')),
                    DataCell(Text(data['price']?.toString() ?? '')),
                    DataCell(Text(data['stock']?.toString() ?? '')),
                    DataCell(Text(data['supplier']?.toString() ?? data['supplierID']?.toString() ?? '')),
                    DataCell(Text(
                      date != null ? _formatTimeAgo(date, DateTime.now()) : '',
                    )),
                  ]);
                } else if (logType == 'jobOrders') {
                  cells.addAll([
                    DataCell(Text(data['name']?.toString() ?? '')),
                    DataCell(Text(data['status']?.toString() ?? '')),
                  ]);
                } else {
                  cells.add(DataCell(Text(data['remarks']?.toString() ?? '')));
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
String _formatTimeAgo(DateTime? date, DateTime now) {
  if (date == null) return '';
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

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