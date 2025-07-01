import 'package:flutter/material.dart';
import '../../backend/fetch_profit.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  double? _profit;
  List<Map<String, dynamic>> _productProfits = [];
  bool _loading = true;

  // Statistics
  int _totalProducts = 0;
  int _totalSold = 0;
  int _totalJobOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadProfit();
  }

Widget _buildBigStatCard({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _loadProfit() async {
    final profit = await fetchUserTotalProfit();
    final productProfits = await fetchUserProductProfits();

    // Calculate statistics
    int totalProducts = productProfits.length;
    int totalSold = 0;
    int totalJobOrders = 0;
    for (final p in productProfits) {
      totalSold += (p['totalQtySold'] ?? 0) as int;
      totalJobOrders += (p['jobOrderCount'] ?? 0) as int;
    }

    setState(() {
      _profit = profit;
      _productProfits = productProfits;
      _totalProducts = totalProducts;
      _totalSold = totalSold;
      _totalJobOrders = totalJobOrders;
      _loading = false;
    });
  }

  double _getMaxProfit() {
    if (_productProfits.isEmpty) return 100;
    final sum = _productProfits
        .map((p) => (p['totalRevenue'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(0, (prev, e) => prev + e);
    return sum < 100 ? 100 : sum * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profit Checker'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfit,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Statistics Row (compact)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBigStatCard(
                        icon: Icons.checkroom,
                        label: 'Products',
                        value: _totalProducts.toString(),
                        color: Colors.blue,
                      ),
                      _buildBigStatCard(
                        icon: Icons.shopping_cart,
                        label: 'Sold',
                        value: _totalSold.toString(),
                        color: Colors.orange,
                      ),
                      _buildBigStatCard(
                        icon: Icons.assignment_turned_in,
                        label: 'Job Orders',
                        value: _totalJobOrders.toString(),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Large Total Profit Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Profit',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 10),
                        Text(
                          '₱${_productProfits
                              .map((p) => (p['totalRevenue'] as num?)?.toDouble() ?? 0.0)
                              .fold<double>(0, (prev, e) => prev + e)
                              .toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Bar Chart
                  if (_productProfits.isNotEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                        child: SizedBox(
                          height: 260,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _getMaxProfit(),
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= _productProfits.length) return const SizedBox();
                                      final name = _productProfits[idx]['name'] ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          name.length > 8 ? '${name.substring(0, 8)}…' : name,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                    interval: 1,
                                  ),
                                ),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(_productProfits.length, (i) {
                                final profit = (_productProfits[i]['totalRevenue'] as num?)?.toDouble() ?? 0.0;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: profit,
                                      color: profit >= 0 ? Colors.green : Colors.red,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_productProfits.isNotEmpty) const SizedBox(height: 18),
                  const Text(
                    'Product Breakdown',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_productProfits.isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._productProfits.map((p) => Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      radius: 22,
                                      child: Icon(Icons.checkroom, color: Colors.blue[700], size: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        p['name'] ?? 'Unnamed Product',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: p['profit'] >= 0 ? Colors.green[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        p['profit'] >= 0 ? 'Profit' : 'Loss',
                                        style: TextStyle(
                                          color: p['profit'] >= 0 ? Colors.green[700] : Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _buildStatItem(
                                      'Sold',
                                      p['totalQtySold'].toString(),
                                      Icons.shopping_cart_outlined,
                                      Colors.orange[700]!,
                                    ),
                                    _buildStatItem(
                                      'Revenue',
                                      '₱${p['totalRevenue'].toStringAsFixed(2)}',
                                      Icons.attach_money,
                                      Colors.green[700]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildStatItem(
                                      'Job Orders',
                                      p['jobOrderCount'].toString(),
                                      Icons.assignment_turned_in,
                                      Colors.blue[700]!,
                                    ),
                                    _buildStatItem(
                                      'Unit Cost',
                                      '₱${p['unitCost'].toStringAsFixed(2)}',
                                      Icons.precision_manufacturing,
                                      Colors.purple[700]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Profit: ₱${p['totalRevenue'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: p['totalRevenue'] >= 0 ? Colors.green[800] : Colors.red[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Chip(
      backgroundColor: color.withOpacity(0.13),
      avatar: Icon(icon, color: color, size: 22),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}