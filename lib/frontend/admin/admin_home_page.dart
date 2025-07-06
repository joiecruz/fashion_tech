import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';
import '../auth/unauthorized_page.dart';
import '../auth/login_page.dart';
import '../logs/productLogs.dart';
import '../logs/jobOrderLogs.dart';
import 'package:intl/intl.dart';

// --- PRODUCT LOGS TAB ---
class ProductLogsTab extends StatefulWidget {
  final bool isAdmin;
  const ProductLogsTab({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<ProductLogsTab> createState() => _ProductLogsTabState();
}

class _ProductLogsTabState extends State<ProductLogsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> addMockProductLog() async {
    await FirebaseFirestore.instance.collection('inventoryLogs').add({
      'productID': 'P1001',
      'supplierID': 'S2001',
      'changeType': 'add',
      'quantityChanged': 50,
      'remarks': 'Initial stock',
      'createdAt': DateTime.now(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'mockUser',
    });
    _fetchLogs();
  }

  Future<void> addMockJobOrderLog() async {
    await FirebaseFirestore.instance.collection('jobOrderLogs').add({
      'jobOrderID': 'JO3001',
      'changeType': 'statusUpdate',
      'previousValue': 'Pending',
      'newValue': 'In Progress',
      'notes': 'Started production',
      'timestamp': DateTime.now(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'mockUser',
    });
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    Query query = FirebaseFirestore.instance.collection('inventoryLogs').orderBy('createdAt', descending: true);
    if (!widget.isAdmin && userId != null) {
      query = query.where('createdBy', isEqualTo: userId);
    }
    final snapshot = await query.get();
    setState(() {
      _logs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'productID': data['productID'] ?? '',
          'supplierID': data['supplierID'] ?? '',
          'changeType': data['changeType'] ?? '',
          'quantityChanged': data['quantityChanged'] ?? 0,
          'remarks': data['remarks'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _deleteLog(String id) async {
    final docRef = FirebaseFirestore.instance.collection('inventoryLogs').doc(id);
    final docSnap = await docRef.get();
    final deletedData = docSnap.data();

    await docRef.delete();
    _fetchLogs();

    if (mounted && deletedData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product log deleted.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              await docRef.set(deletedData);
              _fetchLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete undone!'), backgroundColor: Colors.green),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: addMockProductLog,
                child: const Text('Add Mock Product Log'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: addMockJobOrderLog,
                child: const Text('Add Mock Job Order Log'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const Center(child: Text('No product logs found.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Product ID')),
                              const DataColumn(label: Text('Supplier ID')),
                              const DataColumn(label: Text('Change Type')),
                              const DataColumn(label: Text('Qty')),
                              const DataColumn(label: Text('Remarks')),
                              const DataColumn(label: Text('Date')),
                              const DataColumn(label: Text('Edit')),
                              if (widget.isAdmin) const DataColumn(label: Text('Delete')),
                            ],
                            rows: _logs.map((log) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(log['productID'].toString())),
                                  DataCell(Text(log['supplierID'].toString())),
                                  DataCell(Text(log['changeType'].toString())),
                                  DataCell(Text(log['quantityChanged'].toString())),
                                  DataCell(Text(log['remarks'].toString())),
                                  DataCell(Text(
                                    log['createdAt'] != null
                                        ? DateFormat('yyyy-MM-dd HH:mm').format(log['createdAt'])
                                        : '',
                                  )),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditProductLogPage(
                                              logId: log['id'],
                                              logData: log,
                                            ),
                                          ),
                                        );
                                        _fetchLogs();
                                      },
                                    ),
                                  ),
                                  if (widget.isAdmin)
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          await _deleteLog(log['id']);
                                        },
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- JOB ORDER LOGS TAB ---
class JobOrderLogsTab extends StatefulWidget {
  final bool isAdmin;
  const JobOrderLogsTab({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<JobOrderLogsTab> createState() => _JobOrderLogsTabState();
}

class _JobOrderLogsTabState extends State<JobOrderLogsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    Query query = FirebaseFirestore.instance.collection('jobOrderLogs').orderBy('timestamp', descending: true);
    if (!widget.isAdmin && userId != null) {
      query = query.where('createdBy', isEqualTo: userId);
    }
    final snapshot = await query.get();
    setState(() {
      _logs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'jobOrderID': data['jobOrderID'] ?? '',
          'changeType': data['changeType'] ?? '',
          'previousValue': data['previousValue'] ?? '',
          'newValue': data['newValue'] ?? '',
          'notes': data['notes'] ?? '',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _deleteLog(String id) async {
    final docRef = FirebaseFirestore.instance.collection('jobOrderLogs').doc(id);
    final docSnap = await docRef.get();
    final deletedData = docSnap.data();

    await docRef.delete();
    _fetchLogs();

    if (mounted && deletedData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job order log deleted.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              await docRef.set(deletedData);
              _fetchLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete undone!'), backgroundColor: Colors.green),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
                ? const Center(child: Text('No job order logs found.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('Job Order ID')),
                        const DataColumn(label: Text('Change Type')),
                        const DataColumn(label: Text('Previous')),
                        const DataColumn(label: Text('New Value')),
                        const DataColumn(label: Text('Notes')),
                        const DataColumn(label: Text('Date')),
                        const DataColumn(label: Text('Edit')),
                        if (widget.isAdmin) const DataColumn(label: Text('Delete')),
                      ],
                      rows: _logs.map((log) {
                        return DataRow(
                          cells: [
                            DataCell(Text(log['jobOrderID'].toString())),
                            DataCell(Text(log['changeType'].toString())),
                            DataCell(Text(log['previousValue'].toString())),
                            DataCell(Text(log['newValue'].toString())),
                            DataCell(Text(log['notes'].toString())),
                            DataCell(Text(
                              log['timestamp'] != null
                                  ? DateFormat('yyyy-MM-dd HH:mm').format(log['timestamp'])
                                  : '',
                            )),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditJobOrderLogPage(
                                        logId: log['id'],
                                        logData: log,
                                      ),
                                    ),
                                  );
                                  _fetchLogs();
                                },
                              ),
                            ),
                            if (widget.isAdmin)
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await _deleteLog(log['id']);
                                  },
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
      ),
    );
  }
}

// --- ADMIN HOME PAGE & DASHBOARD ---
// ...rest of your dashboard code (unchanged)...
// --- ADMIN HOME PAGE & DASHBOARD ---
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserService.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.data != true) {
          return const UnauthorizedPage();
        }
        return _AdminDashboard(isAdmin: true);
      },
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  final bool isAdmin;
  const _AdminDashboard({Key? key, required this.isAdmin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings),
                    const SizedBox(width: 4),
                    Text(
                      FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'Admin',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Transactions', icon: Icon(Icons.swap_horiz)),
              Tab(text: 'Job Orders', icon: Icon(Icons.assignment)),
              Tab(text: 'Inventory', icon: Icon(Icons.inventory)),
              Tab(text: 'Product Logs', icon: Icon(Icons.list_alt)),
              Tab(text: 'Job Order Logs', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _OverviewTab(),
            const _UsersTab(),
            const _TransactionsTab(),
            const _JobOrdersTab(),
            const _InventoryTab(),
            ProductLogsTab(isAdmin: isAdmin),
            JobOrderLogsTab(isAdmin: isAdmin),
          ],
        ),
      ),
    );
  }
}

// --- OVERVIEW TAB ---
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards - Responsive layout
          if (isSmallScreen)
            // For small screens: stack 2x2
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: "Sales",
                        icon: Icons.trending_up,
                        color: Colors.green,
                        stream: _AdminDashboardState.totalSalesStream,
                        gradient: LinearGradient(
                          colors: [Colors.green[100]!, Colors.green[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: "Expenses",
                        icon: Icons.trending_down,
                        color: Colors.red,
                        stream: _AdminDashboardState.totalExpensesStream,
                        gradient: LinearGradient(
                          colors: [Colors.red[100]!, Colors.red[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: "Users",
                        icon: Icons.people,
                        color: Colors.deepPurple,
                        stream: _AdminDashboardState.totalUsersStream,
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple[100]!, Colors.deepPurple[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: "Products",
                        icon: Icons.checkroom,
                        color: Colors.blue,
                        stream: _AdminDashboardState.totalProductsStream,
                        gradient: LinearGradient(
                          colors: [Colors.blue[100]!, Colors.blue[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // For larger screens: show all in one row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: _StatCard(
                      title: "Sales",
                      icon: Icons.trending_up,
                      color: Colors.green,
                      stream: _AdminDashboardState.totalSalesStream,
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.green[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _StatCard(
                      title: "Expenses",
                      icon: Icons.trending_down,
                      color: Colors.red,
                      stream: _AdminDashboardState.totalExpensesStream,
                      gradient: LinearGradient(
                        colors: [Colors.red[100]!, Colors.red[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _StatCard(
                      title: "Users",
                      icon: Icons.people,
                      color: Colors.deepPurple,
                      stream: _AdminDashboardState.totalUsersStream,
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple[100]!, Colors.deepPurple[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _StatCard(
                      title: "Products",
                      icon: Icons.checkroom,
                      color: Colors.blue,
                      stream: _AdminDashboardState.totalProductsStream,
                      gradient: LinearGradient(
                        colors: [Colors.blue[100]!, Colors.blue[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Trends Chart
          _modernCard(
            gradient: LinearGradient(
              colors: [Colors.deepPurple[50]!, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Sales & Expenses Trends', Icons.bar_chart),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _TrendsChart(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Category Pie Chart
          _modernCard(
            gradient: LinearGradient(
              colors: [Colors.orange[50]!, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Product Category Distribution', Icons.pie_chart),
                const SizedBox(height: 12),
                _CategoryPieChart(),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Low Stock Alert
          _LowStockAlert(),
        ],
      ),
    );
  }
}

// --- USERS TAB ---
class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _modernCard(
        gradient: LinearGradient(
          colors: [Colors.deepPurple[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Account Management', Icons.people),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final users = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: users.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(data['username'] ?? '')),
                            DataCell(Text(data['email'] ?? '')),
                            DataCell(Text(data['role'] ?? 'user')),
                            DataCell(Text((data['isActive'] ?? true) ? 'Active' : 'Inactive')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.edit), 
                                  onPressed: () {/* Edit logic */}
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.delete), 
                                  onPressed: () {/* Delete logic */}
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- TRANSACTIONS TAB ---
class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _modernCard(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Transaction Control', Icons.swap_horiz),
                TextButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                  onPressed: () {/* Show filter dialog */},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('salesLog')
                        .orderBy('dateSold', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No transactions found'));
                      }
                      final transactions = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 15,
                        horizontalMargin: 10,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: transactions.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(
                              (data['dateSold'] as Timestamp?)?.toDate().toString().split(' ').first ?? '',
                              overflow: TextOverflow.ellipsis,
                            )),
                            DataCell(
                              data['name'] != null
                                  ? Text(data['name'], overflow: TextOverflow.ellipsis)
                                  : data['productId'] != null
                                      ? FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('products')
                                              .doc(data['productId'])
                                              .get(),
                                          builder: (context, productSnapshot) {
                                            if (productSnapshot.connectionState == ConnectionState.waiting) {
                                              return const Text('Loading...');
                                            }
                                            if (productSnapshot.hasError ||
                                                !productSnapshot.hasData ||
                                                !productSnapshot.data!.exists) {
                                              return const Text('Unknown');
                                            }
                                            final productData = productSnapshot.data!.data() as Map<String, dynamic>;
                                            return Text(productData['name'] ?? 'Unknown', overflow: TextOverflow.ellipsis);
                                          },
                                        )
                                      : Text(data['productName'] ?? 'Unknown', overflow: TextOverflow.ellipsis),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Sale',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₱${(data['totalRevenue'] ?? 0).toString()}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(Text('Completed')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () {/* View details */},
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {/* Edit transaction */},
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Fabric expenses section
            const SizedBox(height: 16),
            _sectionTitle('Fabric Expenses', Icons.inventory),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('fabrics')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No fabric expenses found'));
                      }
                      final fabrics = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 15,
                        horizontalMargin: 10,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Fabric')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows: fabrics.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final qty = (data['quantity'] ?? 0) as num;
                          final price = (data['pricePerUnit'] ?? 0) as num;
                          final total = qty * price;
                          return DataRow(cells: [
                            DataCell(Text(
                              (data['createdAt'] as Timestamp?)?.toDate().toString().split(' ').first ?? '',
                              overflow: TextOverflow.ellipsis,
                            )),
                            DataCell(Text(data['name'] ?? 'Unknown', overflow: TextOverflow.ellipsis)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: Colors.red[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(qty.toString())),
                            DataCell(Text('₱${price.toString()}')),
                            DataCell(
                              Text(
                                '₱${total.toString()}',
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ]);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- JOB ORDERS TAB ---
class _JobOrdersTab extends StatelessWidget {
  const _JobOrdersTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _modernCard(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Job Order Oversight', Icons.assignment),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Job Order'),
                  onPressed: () {/* Add new job order */},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    // Try different collection names based on your database structure
                    stream: FirebaseFirestore.instance
                        .collection('jobOrders')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        try {
                          // Try alternate collection name if first one fails
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('joborders') // lowercase alternative
                                .orderBy('createdAt', descending: true)
                                .limit(50)
                                .snapshots(),
                            builder: (context, snapshotAlt) {
                              if (snapshotAlt.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              if (snapshotAlt.hasError) {
                                return Center(child: Text('Error loading job orders: ${snapshotAlt.error}'));
                              }
                              
                              if (!snapshotAlt.hasData || snapshotAlt.data!.docs.isEmpty) {
                                return const Center(child: Text('No job orders found'));
                              }
                              
                              final jobs = snapshotAlt.data!.docs;
                              return _buildJobOrdersTable(jobs);
                            },
                          );
                        } catch (e) {
                          return Center(child: Text('Error: $e'));
                        }
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No job orders found'));
                      }
                      
                      final jobs = snapshot.data!.docs;
                      return _buildJobOrdersTable(jobs);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildJobOrdersTable(List<QueryDocumentSnapshot> jobs) {
    return DataTable(
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Order #')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Due Date')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Actions')),
      ],
      rows: jobs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DataRow(cells: [
          DataCell(Text(doc.id)),
          DataCell(Text(data['customer'] ?? data['customerName'] ?? '')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(data['status'] ?? 'Pending'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data['status'] ?? 'Pending',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          DataCell(Text((data['dueDate'] as Timestamp?)?.toDate().toString().split(' ').first ?? 'N/A')),
          DataCell(Text('₱${(data['totalAmount'] ?? 0).toString()}')),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.visibility),
                onPressed: () {/* View details */}
              ),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.edit), 
                onPressed: () {/* Edit logic */}
              ),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.delete), 
                onPressed: () {/* Delete logic */}
              ),
            ],
          )),
        ]);
      }).toList(),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// --- INVENTORY TAB ---
class _InventoryTab extends StatelessWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _modernCard(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Inventory Management', Icons.inventory),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Item'),
                  onPressed: () {/* Add item logic */},
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Inventory filter/search
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  // Implement search functionality
                },
              ),
            ),
            
            // Products section
            _sectionTitle('Products', Icons.shopping_bag),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No products found'));
                      }
                      
                      final products = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: products.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: data['imageURL'] != null
                                    ? Image.network(
                                        data['imageURL'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image_not_supported, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image, size: 20),
                                      ),
                              ),
                            ),
                            DataCell(Text(data['name'] ?? '')),
                            DataCell(Text(data['type'] ?? 'Product')),
                            DataCell(
                              Text(
                                '${data['quantity'] ?? 0}',
                                style: TextStyle(
                                  color: (data['quantity'] ?? 0) < 10 ? Colors.red : Colors.black,
                                  fontWeight: (data['quantity'] ?? 0) < 10 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            DataCell(Text('₱${(data['price'] ?? 0).toString()}')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.edit), 
                                  onPressed: () {/* Edit logic */}
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.add), 
                                  onPressed: () {/* Add stock */}
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.remove), 
                                  onPressed: () {/* Remove stock */}
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Fabrics section
            const SizedBox(height: 20),
            _sectionTitle('Fabrics', Icons.texture),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('fabrics')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No fabrics found'));
                      }
                      
                      final fabrics = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Price/Unit')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: fabrics.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: data['imageURL'] != null
                                    ? Image.network(
                                        data['imageURL'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image_not_supported, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.texture, size: 20),
                                      ),
                              ),
                            ),
                            DataCell(Text(data['name'] ?? '')),
                            DataCell(Text(data['fabricType'] ?? 'Fabric')),
                            DataCell(
                              Text(
                                '${data['quantity'] ?? 0}',
                                style: TextStyle(
                                  color: (data['quantity'] ?? 0) < 10 ? Colors.red : Colors.black,
                                  fontWeight: (data['quantity'] ?? 0) < 10 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            DataCell(Text('₱${(data['pricePerUnit'] ?? 0).toString()}')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.edit), 
                                  onPressed: () {/* Edit logic */}
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.add), 
                                  onPressed: () {/* Add stock */}
                                ),
                                IconButton(
                                  iconSize: 20,
                                  icon: const Icon(Icons.remove), 
                                  onPressed: () {/* Remove stock */}
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CHARTS & CARDS ---
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<dynamic> stream;
  final Gradient gradient;
  
  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return _modernCard(
          gradient: gradient,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${value is double ? value.toStringAsFixed(0) : value}",
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: color
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12, 
                        color: Colors.black54, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrendsChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    Future<Map<String, List<double>>> getTrendsData() async {
      final now = DateTime.now();
      final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
      List<double> sales = List.filled(6, 0);
      List<double> expenses = List.filled(6, 0);

      // Fetch sales from salesLog
      final salesTxs = await FirebaseFirestore.instance
          .collection('salesLog')
          .where('dateSold', isGreaterThanOrEqualTo: months.first)
          .get();

      for (var doc in salesTxs.docs) {
        final data = doc.data();
        final date = (data['dateSold'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final idx = months.indexWhere((m) => m.month == date.month && m.year == date.year);
        if (idx == -1) continue;
        sales[idx] += (data['totalRevenue'] as num?)?.toDouble() ?? 0;
      }
      
      // Fetch expenses from fabrics
      final expenseTxs = await FirebaseFirestore.instance
          .collection('fabrics')
          .where('createdAt', isGreaterThanOrEqualTo: months.first)
          .get();

      for (var doc in expenseTxs.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;
        final idx = months.indexWhere((m) => m.month == createdAt.month && m.year == createdAt.year);
        if (idx == -1) continue;
        final qty = (data['quantity'] ?? 0) as num;
        final price = (data['pricePerUnit'] ?? 0) as num;
        expenses[idx] += qty * price;
      }

      return {
        'sales': sales,
        'expenses': expenses,
      };
    }

    final months = List.generate(6, (i) {
      final now = DateTime.now();
      final m = DateTime(now.year, now.month - 5 + i, 1);
      return "${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m.month-1]}";
    });

    return FutureBuilder<Map<String, List<double>>>(
      future: getTrendsData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sales = snapshot.data!['sales']!;
        final expenses = snapshot.data!['expenses']!;
        
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barGroups: List.generate(
              isSmallScreen ? 3 : 6, // Show fewer bars on small screens
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: isSmallScreen ? sales[i + 3] : sales[i], // Show most recent months on small screens
                    color: Colors.green,
                    width: isSmallScreen ? 8 : 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: isSmallScreen ? expenses[i + 3] : expenses[i],
                    color: Colors.red,
                    width: isSmallScreen ? 8 : 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    // Responsive y-axis labels
                    if (value == 0) {
                      return const Text('0', style: TextStyle(fontSize: 10));
                    } else if (value % 1000 == 0) {
                      return Text('${(value/1000).toInt()}k', style: TextStyle(fontSize: 10));
                    }
                    return const SizedBox.shrink();
                  }
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    final monthIdx = isSmallScreen ? idx + 3 : idx; // Adjust for small screens
                    return monthIdx >= 0 && monthIdx < months.length
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[monthIdx], 
                              style: const TextStyle(fontSize: 10),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    Future<Map<String, double>> getCategoryDistribution() async {
      final products = await FirebaseFirestore.instance.collection('products').get();
      Map<String, double> categoryCounts = {};
      for (var doc in products.docs) {
        final data = doc.data();
        final cat = data['categoryID'] ?? 'Uncategorized';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
      return categoryCounts;
    }

    return FutureBuilder<Map<String, double>>(
      future: getCategoryDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(height: 160, child: Center(child: Text("No data")));
        }
        final data = snapshot.data!;
        final total = data.values.fold<double>(0, (a, b) => a + b);
        final colors = [
          Colors.deepPurple,
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.pink,
          Colors.teal,
          Colors.brown,
        ];
        
        return SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sections: data.entries.map((e) {
                final idx = data.keys.toList().indexOf(e.key);
                return PieChartSectionData(
                  color: colors[idx % colors.length],
                  value: e.value,
                  title: isSmallScreen ? "" : "${((e.value / total) * 100).toStringAsFixed(1)}%",
                  radius: isSmallScreen ? 40 : 48,
                  titleStyle: const TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                );
              }).toList(),
              sectionsSpace: isSmallScreen ? 1 : 2,
              centerSpaceRadius: isSmallScreen ? 20 : 24,
            ),
          ),
        );
      },
    );
  }
}

class _LowStockAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Stream<List<Map<String, dynamic>>> lowStockFabricsStream = FirebaseFirestore.instance
        .collection('fabrics')
        .where('quantity', isLessThan: 10)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: lowStockFabricsStream,
      builder: (context, snapshot) {
        final fabrics = snapshot.data ?? [];
        if (fabrics.isEmpty) return const SizedBox.shrink();
        return _modernCard(
          gradient: LinearGradient(
            colors: [Colors.red[100]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Low Stock Alert!', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...fabrics.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "${f['name'] ?? 'Unknown'}: ${f['quantity'] ?? 0} left",
                  style: const TextStyle(
                    color: Colors.red, 
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

// --- UI Helpers ---
Widget _modernCard({required Widget child, Color? color, Gradient? gradient}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: gradient == null ? (color ?? Colors.white) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

Widget _sectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: Colors.deepPurple[400], size: 20),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[900],
        ),
      ),
    ],
  );
}

class _AdminDashboardState {
  static Stream<double> get totalSalesStream => FirebaseFirestore.instance
      .collection('salesLog')
      .snapshots()
      .map((snap) => snap.docs.fold<double>(
          0, (sum, doc) => sum + (((doc.data() as Map)['totalRevenue'] as num?)?.toDouble() ?? 0.0)));

  static Stream<double> get totalExpensesStream => FirebaseFirestore.instance
      .collection('fabrics')
      .snapshots()
      .map((snap) => snap.docs.fold<double>(
          0,
          (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final qty = (data['quantity'] ?? 0) as num;
            final price = (data['pricePerUnit'] ?? 0) as num;
            return sum + (qty * price);
          },
      ));

  static Stream<int> get totalUsersStream => FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalProductsStream => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((snap) => snap.docs.length);
}