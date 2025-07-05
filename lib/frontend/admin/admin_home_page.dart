import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({Key? key}) : super(key: key);

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
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Transactions', icon: Icon(Icons.swap_horiz)),
              Tab(text: 'Job Orders', icon: Icon(Icons.assignment)),
              Tab(text: 'Inventory', icon: Icon(Icons.inventory)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _UsersTab(),
            _TransactionsTab(),
            _JobOrdersTab(),
            _InventoryTab(),
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
            _sectionTitle('Transaction Control', Icons.swap_horiz),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final txs = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: txs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text((data['date'] as Timestamp?)?.toDate().toString().split(' ').first ?? '')),
                            DataCell(Text(data['user'] ?? '')),
                            DataCell(Text(data['type'] ?? '')),
                            DataCell(Text('₱${(data['amount'] ?? 0).toString()}')),
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
            _sectionTitle('Job Order Oversight', Icons.assignment),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('joborders').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final jobs = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Order #')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Due')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: jobs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(doc.id)),
                            DataCell(Text(data['customer'] ?? '')),
                            DataCell(Text(data['status'] ?? '')),
                            DataCell(Text((data['dueDate'] as Timestamp?)?.toDate().toString().split(' ').first ?? '')),
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
            _sectionTitle('Inventory Management', Icons.inventory),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('products').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final products = snapshot.data!.docs;
                      return DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: products.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(data['name'] ?? '')),
                            DataCell(Text(data['type'] ?? 'Product')),
                            DataCell(Text('${data['quantity'] ?? 0}')),
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

// --- Static streams for stat cards ---
class _AdminDashboardState {
  static Stream<double> get totalSalesStream => FirebaseFirestore.instance
      .collection('salesLog')
      .snapshots()
      .map((snap) => snap.docs.fold<double>(
          0, (sum, doc) => sum + (((doc.data() as Map)['totalRevenue'] as num?)?.toDouble() ?? 0.0)));

  // EXPENSES: Sum of (quantity * pricePerUnit) for all fabrics
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