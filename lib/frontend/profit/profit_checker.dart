import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/fetch_profit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  List<Map<String, dynamic>> _productProfits = [];
  bool _loading = true;

  // Statistics
  int _totalProducts = 0;
  int _totalSold = 0;
  int _totalJobOrders = 0;
  final user = FirebaseAuth.instance.currentUser;
  String? userId;
  // Sales vs Expenses
  double? _totalSales;
  double? _totalExpenses;

  // Fabric breakdown
  List<Map<String, dynamic>> _fabrics = [];

  // Product details
  List<Map<String, dynamic>> _products = [];

  // --- UI constants ---
  final _cardRadius = BorderRadius.circular(20);
  final _shadowColor = Colors.black.withOpacity(0.08);
  final _cardElevation = 8.0;

  @override
  void initState() {
    super.initState();
    userId = user?.uid;
    _fetchFabrics();
    _loadProfit();
  }

  Future<double> _fetchTotalSales() async {
    final salesSnap = await FirebaseFirestore.instance
        .collection('salesLog')
        .where('soldBy', isEqualTo: userId)
        .get();
    double total = 0;
    for (final doc in salesSnap.docs) {
      total += (doc.data()['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<double> _fetchTotalExpenses() async {
    double totalExpense = 0.0;
    final snapshot = await FirebaseFirestore.instance
        .collection('fabrics')
        .where('createdBy', isEqualTo: userId)
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final quantity = (data['quantity'] ?? 0) as num;
      final pricePerUnit = (data['pricePerUnit'] ?? 0) as num;
      totalExpense += quantity * pricePerUnit;
    }
    return totalExpense;
  }

  Future<void> _fetchFabrics() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fabrics')
        .where('createdBy', isEqualTo: userId)
        .get();
    setState(() {
      _fabrics = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? 'Unnamed Fabric',
          'quantity': (data['quantity'] ?? 0) as num,
          'pricePerUnit': (data['pricePerUnit'] ?? 0) as num,
          'image': data['swatchImageURL'] ?? data['imageURL'] ?? data['imageBase64'] ?? '',
        };
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('createdBy', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['name'] ?? '',
        'image': data['image'] ?? data['imageURL'] ?? data['imageBase64'] ?? '',
        // add other fields if needed
      };
    }).toList();
  }

  Future<void> _loadProfit() async {
    final productProfits = await fetchUserProductProfits();
    final totalSales = await _fetchTotalSales();
    final totalExpenses = await _fetchTotalExpenses();
    final products = await _fetchProducts();

    // Calculate statistics and patch image if missing
    int totalProducts = productProfits.length;
    int totalSold = 0;
    int totalJobOrders = 0;
    for (final p in productProfits) {
      totalSold += (p['totalQtySold'] ?? 0) as int;
      totalJobOrders += (p['jobOrderCount'] ?? 0) as int;

      // Try to get image from product details
      String image = p['image'] ?? p['imageURL'] ?? p['imageUrl'] ?? p['imageBase64'] ?? '';
      if (image.isEmpty && p['name'] != null) {
        final product = products.firstWhere(
          (prod) => (prod['name'] ?? '').toString().toLowerCase() == p['name'].toString().toLowerCase(),
          orElse: () => {},
        );
        if (product.isNotEmpty) {
          image = product['image'] ?? '';
        }
      }
      // Fallback to fabric image if still empty
      if (image.isEmpty && p['fabricName'] != null) {
        final fabric = _fabrics.firstWhere(
          (f) => (f['name'] ?? '').toString().toLowerCase() == p['fabricName'].toString().toLowerCase(),
          orElse: () => {},
        );
        if (fabric.isNotEmpty) {
          image = fabric['image'] ?? '';
        }
      }
      p['image'] = image;
    }

    setState(() {
      _productProfits = productProfits;
      _products = products;
      _totalProducts = totalProducts;
      _totalSold = totalSold;
      _totalJobOrders = totalJobOrders;
      _totalSales = totalSales;
      _totalExpenses = totalExpenses;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final netProfit = ((_totalSales ?? 0) - (_totalExpenses ?? 0));
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 400 ? 10.0 : 20.0;

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
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Total Profit Card (Large, subtle gradient) ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 22),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 400 ? 16 : 24,
                      vertical: screenWidth < 400 ? 16 : 28,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Profit',
                          style: TextStyle(
                            fontSize: 28, // Reduced from 28
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '₱${netProfit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36, // Reduced from 54
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, color: Colors.green[700], size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Sales: ₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_down, color: Colors.red[700], size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Expenses: ₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Profit = Sales - Expenses',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Stats Row (Lighter gradients) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        // First Stats Row
                        Row(
                          children: [
                            _buildBigStatCard(
                              icon: Icons.trending_up,
                              label: 'Sales',
                              value: '₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                              color: Colors.green,
                              gradientColors: [
                                Colors.green.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Total Revenue',
                            ),
                            _buildBigStatCard(
                              icon: Icons.trending_down,
                              label: 'Expenses',
                              value: '₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                              color: Colors.red,
                              gradientColors: [
                                Colors.red.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Total Costs',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Second Stats Row
                        Row(
                          children: [
                            _buildBigStatCard(
                              icon: Icons.checkroom,
                              label: 'Products',
                              value: _totalProducts.toString(),
                              color: Colors.blue,
                              gradientColors: [
                                Colors.blue.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'In Inventory',
                            ),
                            _buildBigStatCard(
                              icon: Icons.shopping_cart,
                              label: 'Sold',
                              value: _totalSold.toString(),
                              color: Colors.orange,
                              gradientColors: [
                                Colors.orange.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Items',
                            ),
                            _buildBigStatCard(
                              icon: Icons.assignment_turned_in,
                              label: 'Job Orders',
                              value: _totalJobOrders.toString(),
                              color: Colors.purple,
                              gradientColors: [
                                Colors.purple.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Active',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- Product Breakdown Section ---
                  const Text(
                    'Product Breakdown',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_productProfits.where((p) => (p['totalQtySold'] ?? 0) > 0 && (p['totalRevenue'] ?? 0) != 0).isEmpty)
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
                              'No products with sales or profit found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._productProfits
                        .where((p) => (p['totalQtySold'] ?? 0) > 0 && (p['totalRevenue'] ?? 0) != 0)
                        .map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10), // More vertical space
                              child: _buildProductBreakdownCard(p),
                            )),

                  // --- Fabric Breakdown Section ---
                  const SizedBox(height: 22),
                  const Text(
                    'Fabric Breakdown',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_fabrics.where((f) => ((f['quantity'] ?? 0) as num) * ((f['pricePerUnit'] ?? 0) as num) > 0).isEmpty)
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
                              'No fabrics with expenses found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._fabrics
                        .where((f) => ((f['quantity'] ?? 0) as num) * ((f['pricePerUnit'] ?? 0) as num) > 0)
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10), // More vertical space
                              child: _buildFabricBreakdownCard(f),
                            )),
                ],
              ),
            ),
    );
  }

  Widget _buildBigStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required List<Color> gradientColors,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: _cardRadius,
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: _cardElevation,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color.withOpacity(0.7), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for product/fabric images (base64, network, fallback)
  Widget _buildImage(String? imageUrl, {double size = 48, IconData fallbackIcon = Icons.image}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(fallbackIcon, size: size * 0.5, color: Colors.grey[400]);
    }
    if (imageUrl.startsWith('data:image')) {
      final base64Data = imageUrl.split(',').last;
      try {
        final decoded = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 4),
          child: Image.memory(
            decoded,
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        );
      } catch (e) {
        return Icon(Icons.broken_image, size: size * 0.5, color: Colors.red[300]);
      }
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(fallbackIcon, color: Colors.grey[400], size: size * 0.5);
          },
        ),
      );
    } else {
      return Icon(fallbackIcon, size: size * 0.5, color: Colors.grey[400]);
    }
  }

  // --- Product Breakdown Card ---
  Widget _buildProductBreakdownCard(Map<String, dynamic> p) {
    final bool isProfit = (p['totalRevenue'] ?? 0) >= 0;
    final double unitCost = (p['unitCost'] ?? 0).toDouble();
    final image = p['image'] ?? p['imageURL'] ?? p['imageUrl'] ?? p['imageBase64'] ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // More space
        child: Row(
          children: [
            _buildImage(
              image,
              size: 48,
              fallbackIcon: Icons.checkroom,
            ),
            const SizedBox(width: 20), // More space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _buildStatItem(
                        Icons.shopping_cart_outlined,
                        Colors.orange[700]!,
                        'Sold: ${(p['totalQtySold'] ?? 0)}',
                      ),
                      _buildStatItem(
                        Icons.attach_money,
                        Colors.green[700]!,
                        '₱${unitCost.toStringAsFixed(2)}/unit',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isProfit ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isProfit ? 'Sales' : 'Loss',
                    style: TextStyle(
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₱${(p['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Fabric Breakdown Card ---
  Widget _buildFabricBreakdownCard(Map<String, dynamic> fabric) {
    final totalExpense = (fabric['quantity'] as num) * (fabric['pricePerUnit'] as num);
    final pricePerUnit = (fabric['pricePerUnit'] as num).toDouble();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // More space
        child: Row(
          children: [
            _buildImage(
              fabric['image'],
              size: 48,
              fallbackIcon: Icons.texture,
            ),
            const SizedBox(width: 20), // More space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fabric['name'] ?? 'Unnamed Fabric',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _buildStatItem(
                        Icons.inventory_2,
                        Colors.orange[700]!,
                        'Qty: ${fabric['quantity']}',
                      ),
                      _buildStatItem(
                        Icons.attach_money,
                        Colors.green[700]!,
                        '₱${pricePerUnit.toStringAsFixed(2)}/unit',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Expense',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₱${totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String text, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}