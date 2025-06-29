import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Fetches the total profit for all products created by the currently logged-in user.
Future<double> fetchUserTotalProfit() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;

  // Get all products created by this user
  final productsSnapshot = await FirebaseFirestore.instance
      .collection('products')
      .where('createdBy', isEqualTo: user.uid)
      .get();

  double totalProfit = 0;

  for (final productDoc in productsSnapshot.docs) {
    final productID = productDoc.id;
    totalProfit += await fetchProductProfit(productID);
  }

  return totalProfit;
}

/// Fetches the profit for a specific product by productID.
Future<double> fetchProductProfit(String productID) async {
  final salesSnapshot = await FirebaseFirestore.instance
      .collection('salesLog')
      .where('productID', isEqualTo: productID)
      .get();

  double totalRevenue = 0;
  int totalQtySold = 0;

  for (final doc in salesSnapshot.docs) {
    final sale = doc.data();
    totalRevenue += (sale['totalRevenue'] ?? 0).toDouble();
    totalQtySold += (sale['qtySold'] ?? 0).toInt() as int;
  }

  final productDoc = await FirebaseFirestore.instance
      .collection('products')
      .doc(productID)
      .get();

  final unitCost = (productDoc.data()?['unitCostEstimate'] ?? 0).toDouble();
  final totalCost = unitCost * totalQtySold;

  return totalRevenue - totalCost;
}

/// Fetches a detailed profit breakdown for each product created by the current user,
/// including the number of job orders for each product.
Future<List<Map<String, dynamic>>> fetchUserProductProfits() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final productsSnapshot = await FirebaseFirestore.instance
      .collection('products')
      .where('createdBy', isEqualTo: user.uid)
      .get();

  List<Map<String, dynamic>> productProfits = [];

  for (final productDoc in productsSnapshot.docs) {
    final productID = productDoc.id;
    final productData = productDoc.data();

    // Fetch profit for this product
    final profit = await fetchProductProfit(productID);

    // Fetch total quantity sold and revenue for this product
    final salesSnapshot = await FirebaseFirestore.instance
        .collection('salesLog')
        .where('productID', isEqualTo: productID)
        .get();

    double totalRevenue = 0;
    int totalQtySold = 0;
    for (final doc in salesSnapshot.docs) {
      final sale = doc.data();
      totalRevenue += (sale['totalRevenue'] ?? 0).toDouble();
      totalQtySold += (sale['qtySold'] ?? 0).toInt() as int;
    } 

    // Fetch job order count for this product
    final jobOrderSnapshot = await FirebaseFirestore.instance
        .collection('jobOrder')
        .where('productID', isEqualTo: productID)
        .get();
    final jobOrderCount = jobOrderSnapshot.size;

    productProfits.add({
      'productID': productID,
      'name': productData['name'] ?? '',
      'totalRevenue': totalRevenue,
      'totalQtySold': totalQtySold,
      'unitCost': (productData['unitCostEstimate'] ?? 0).toDouble(),
      'profit': profit,
      'jobOrderCount': jobOrderCount,
    });
  }

  return productProfits;
}