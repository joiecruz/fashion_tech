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
      length: 5,
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
              Tab(text: 'Product Logs', icon: Icon(Icons.list_alt)),
              Tab(text: 'Job Order Logs', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _OverviewTab(),
            _UserTab(),
            _TransactionsTab(),
            ProductLogsTab(isAdmin: isAdmin),
            JobOrderLogsTab(isAdmin: isAdmin),
          ],
        ),
      ),
    );
  }
}
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. USER STATISTICS
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('User Statistics', Icons.people),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: "Total Users",
                      icon: Icons.people,
                      color: Colors.deepPurple,
                      stream: _AdminDashboardState.totalUsersStream,
                    ),
                    _StatCard(
                      title: "Owners",
                      icon: Icons.verified_user,
                      color: Colors.blueGrey,
                      stream: _AdminDashboardState.usersByRoleStream('owner'),
                    ),
                    _StatCard(
                      title: "Admins",
                      icon: Icons.admin_panel_settings,
                      color: Colors.blue,
                      stream: _AdminDashboardState.usersByRoleStream('admin'),
                    ),
                    _StatCard(
                      title: "Staff",
                      icon: Icons.group,
                      color: Colors.teal,
                      stream: _AdminDashboardState.usersByRoleStream('staff'),
                    ),
                    _StatCard(
                      title: "New This Month",
                      icon: Icons.fiber_new,
                      color: Colors.green,
                      stream: _AdminDashboardState.newUsersThisMonthStream,
                    ),
                    _StatCard(
                      title: "Inactive (30d)",
                      icon: Icons.person_off,
                      color: Colors.red,
                      stream: _AdminDashboardState.inactiveUsersStream,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TopUsersSection()),
                    const SizedBox(width: 24),
                    Expanded(child: _UnderperformingUsersSection()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. SYSTEM DATA OVERVIEW
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('System Data Overview', Icons.dashboard_customize),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: "Products",
                      icon: Icons.checkroom,
                      color: Colors.blue,
                      stream: _AdminDashboardState.totalProductsStream,
                    ),
                    _StatCard(
                      title: "Variants",
                      icon: Icons.style,
                      color: Colors.orange,
                      stream: _AdminDashboardState.totalVariantsStream,
                    ),
                    _StatCard(
                      title: "Fabrics",
                      icon: Icons.texture,
                      color: Colors.purple,
                      stream: _AdminDashboardState.totalFabricsStream,
                    ),
                    _StatCard(
                      title: "Job Orders",
                      icon: Icons.assignment,
                      color: Colors.green,
                      stream: _AdminDashboardState.totalJobOrdersStream,
                    ),
                    _StatCard(
                      title: "Customers",
                      icon: Icons.person,
                      color: Colors.indigo,
                      stream: _AdminDashboardState.totalCustomersStream,
                    ),
                    _StatCard(
                      title: "Transactions",
                      icon: Icons.swap_horiz,
                      color: Colors.brown,
                      stream: _AdminDashboardState.totalTransactionsStream,
                    ),
                    _StatCard(
                      title: "Categories",
                      icon: Icons.category,
                      color: Colors.cyan,
                      stream: _AdminDashboardState.totalCategoriesStream,
                    ),
                    _StatCard(
                      title: "Colors",
                      icon: Icons.color_lens,
                      color: Colors.pink,
                      stream: _AdminDashboardState.totalColorsStream,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _GrowthStatsSection(),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. LOG SNAPSHOT
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Log Snapshot', Icons.receipt_long),
                const SizedBox(height: 12),
                _LogsPreviewSection(),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. SYSTEM HEALTH / ADMIN INSIGHTS
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('System Health & Warnings', Icons.warning_amber_rounded),
                const SizedBox(height: 12),
                _SystemHealthSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- STAT CARD WIDGET ---
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<dynamic> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${value is double ? value.toStringAsFixed(0) : value}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
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

// --- SECTION TITLE ---
Widget _sectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: Colors.deepPurple[400], size: 22),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ],
  );
}

// --- MODERN CARD ---
Widget _modernCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}
class _TopUsersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Fetch all users except admins
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
        // Filter out admin users
        final users = userSnap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? '').toLowerCase() != 'admin';
        }).toList();
        if (users.isEmpty) return const Text('No users found.');
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsersWithCompletedJobOrders(users),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final userStats = snapshot.data!;
            if (userStats.isEmpty) return const Text('No top users found.');
            // Sort descending by completed count
            userStats.sort((a, b) => b['completed'] - a['completed']);
            final topUsers = userStats.take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_up, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Top Performing Users', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...topUsers.map((user) => ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: Text(user['fullName'] ?? user['userID']),
                  subtitle: Text('Job Orders Completed: ${user['completed']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                )),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getUsersWithCompletedJobOrders(List<QueryDocumentSnapshot> users) async {
    List<Map<String, dynamic>> stats = [];
    for (final user in users) {
      final userID = user.id;
      final userData = user.data() as Map<String, dynamic>;
      final jobOrdersSnap = await FirebaseFirestore.instance
          .collection('jobOrders')
          .where('assignedTo', isEqualTo: userID)
          .where('status', isEqualTo: 'Done')
          .get();
      stats.add({
        'userID': userID,
        'fullName': userData['fullName'] ?? userData['fullname'] ?? userID,
        'completed': jobOrdersSnap.docs.length,
      });
    }
    return stats;
  }
}

class _UnderperformingUsersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Fetch all users except admins
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
        // Filter out admin users
        final users = userSnap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? '').toLowerCase() != 'admin';
        }).toList();
        if (users.isEmpty) return const Text('No users found.');
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsersWithCompletedJobOrders(users),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final userStats = snapshot.data!;
            if (userStats.isEmpty) return const Text('No underperforming users found.');
            // Sort ascending by completed count
            userStats.sort((a, b) => a['completed'] - b['completed']);
            final bottomUsers = userStats.take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_down, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('Underperforming Users', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...bottomUsers.map((user) => ListTile(
                  leading: const Icon(Icons.warning, color: Colors.redAccent),
                  title: Text(user['fullName'] ?? user['userID']),
                  subtitle: Text('Job Orders Completed: ${user['completed']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                )),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getUsersWithCompletedJobOrders(List<QueryDocumentSnapshot> users) async {
    List<Map<String, dynamic>> stats = [];
    for (final user in users) {
      final userID = user.id;
      final userData = user.data() as Map<String, dynamic>;
      final jobOrdersSnap = await FirebaseFirestore.instance
          .collection('jobOrders')
          .where('assignedTo', isEqualTo: userID)
          .where('status', isEqualTo: 'Done')
          .get();
      stats.add({
        'userID': userID,
        'fullName': userData['fullName'] ?? userData['fullname'] ?? userID,
        'completed': jobOrdersSnap.docs.length,
      });
    }
    return stats;
  }
}
// --- GROWTH STATS SECTION ---
class _GrowthStatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Replace with your actual Firestore queries for growth stats
    return Row(
      children: [
        const Icon(Icons.trending_up, color: Colors.green, size: 18),
        const SizedBox(width: 6),
        Text(
          '+15% job orders vs. last month',
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// --- LOG SNAPSHOT SECTION ---
class _LogsPreviewSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Job Order Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        _RecentLogsList(collection: 'jobOrderLogs', timeField: 'timestamp'),
        const SizedBox(height: 8),
        const Text('Account Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        _RecentLogsList(collection: 'accountLogs', timeField: 'timestamp'),
        const SizedBox(height: 8),
        const Text('System Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        _RecentLogsList(collection: 'systemLogs', timeField: 'timestamp'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            DefaultTabController.of(context)?.animateTo(5); // Adjust index as needed
          },
          child: const Text('View All Logs'),
        ),
      ],
    );
  }
}

class _RecentLogsList extends StatelessWidget {
  final String collection;
  final String timeField;
  const _RecentLogsList({required this.collection, required this.timeField});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection(collection)
          .orderBy(timeField, descending: true)
          .limit(5)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No logs.');
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.event_note, size: 20),
              title: Text(data['notes'] ?? data['description'] ?? 'No description'),
              subtitle: Text(
                '${data['changedBy'] ?? data['user'] ?? 'System'} • ${data[timeField] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data[timeField] as Timestamp).toDate()) : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- SYSTEM HEALTH / ADMIN INSIGHTS SECTION ---
class _SystemHealthSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fabrics running low in stock
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fabrics')
              .where('quantity', isLessThan: 10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('Low Stock Fabrics', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['name'] ?? 'Unknown'}: ${data['quantity']} left', style: const TextStyle(color: Colors.red));
                }),
              ],
            );
          },
        ),
        // Products without variants
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('products')
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final products = snapshot.data!.docs;
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('productVariants').get(),
              builder: (context, variantSnap) {
                if (!variantSnap.hasData) return const SizedBox();
                final variants = variantSnap.data!.docs;
                final productIdsWithVariants = variants.map((v) => (v.data() as Map<String, dynamic>)['productID']).toSet();
                final productsWithoutVariants = products.where((p) => !productIdsWithVariants.contains(p.id)).toList();
                if (productsWithoutVariants.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text('Products without variants', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ...productsWithoutVariants.map((p) {
                      final data = p.data() as Map<String, dynamic>;
                      return Text('${data['name'] ?? p.id}', style: const TextStyle(color: Colors.orange));
                    }),
                  ],
                );
              },
            );
          },
        ),
        // Job Orders without linked product
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobOrders')
              .where('productID', isNull: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.purple, size: 18),
                    SizedBox(width: 6),
                    Text('Job Orders without linked product', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['name'] ?? doc.id}', style: const TextStyle(color: Colors.purple));
                }),
              ],
            );
          },
        ),
        // Customers missing info
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .where('contactNum', isNull: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.blue, size: 18),
                    SizedBox(width: 6),
                    Text('Customers missing contact info', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['fullName'] ?? doc.id}', style: const TextStyle(color: Colors.blue));
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// --- DASHBOARD STATE STREAMS ---
class _AdminDashboardState {
  static Stream<int> get totalUsersStream => FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> usersByRoleStream(String role) => FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: role)
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get newUsersThisMonthStream {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    return FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> get inactiveUsersStream {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return FirebaseFirestore.instance
        .collection('users')
        .where('lastActive', isLessThan: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> get totalProductsStream => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalVariantsStream => FirebaseFirestore.instance
      .collection('productVariants')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalFabricsStream => FirebaseFirestore.instance
      .collection('fabrics')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalJobOrdersStream => FirebaseFirestore.instance
      .collection('jobOrders')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalCustomersStream => FirebaseFirestore.instance
      .collection('customers')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalTransactionsStream => FirebaseFirestore.instance
      .collection('transactions')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalCategoriesStream => FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalColorsStream => FirebaseFirestore.instance
      .collection('colors')
      .snapshots()
      .map((snap) => snap.docs.length);
}
class _UserTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _modernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('All Users', Icons.people),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No users found.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Active')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(Text(data['fullname'] ?? '')),
                          DataCell(Text(data['role'] ?? '')),
                          DataCell(Text(data['email'] ?? '')),
                          DataCell(Icon(
                            (data['isActive'] ?? true) ? Icons.check_circle : Icons.cancel,
                            color: (data['isActive'] ?? true) ? Colors.green : Colors.red,
                            size: 18,
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _modernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Transactions', Icons.swap_horiz),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('transactions').orderBy('date', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No transactions found.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Date')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(Text(
                            data['type'] is List
                                ? (data['type'] as List).map((e) => e.toString()).join(', ')
                                : (data['type'] ?? ''),
                          )),
                          DataCell(Text(
                            data['category'] is List
                                ? (data['category'] as List).map((e) => e.toString()).join(', ')
                                : (data['category'] ?? ''),
                          )),
                          DataCell(Text('${data['amount'] ?? 0}')),
                          DataCell(Text(
                            data['date'] != null
                                ? DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())
                                : '',
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
