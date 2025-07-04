import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'customers';

  // Get current user ID
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  // Get all customers
  Stream<List<Customer>> getCustomers() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Customer.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return Customer.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting customer: $e');
      return null;
    }
  }

  // Add new customer
  Future<String?> addCustomer(Customer customer) async {
    try {
      DocumentReference docRef = await _firestore.collection(_collectionName).add({
        ...customer.toMap(),
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error adding customer: $e');
      return null;
    }
  }

  // Update customer
  Future<bool> updateCustomer(String id, Customer customer) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        ...customer.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  // Delete customer
  Future<bool> deleteCustomer(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  // Get customer count
  Future<int> getCustomerCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.size;
    } catch (e) {
      print('Error getting customer count: $e');
      return 0;
    }
  }

  // Get customers with job orders count
  Future<Map<String, int>> getCustomersWithJobOrdersCount() async {
    try {
      Map<String, int> result = {};
      
      // Get all customers
      QuerySnapshot customers = await _firestore.collection(_collectionName).get();
      
      // Get job orders grouped by customer
      QuerySnapshot jobOrders = await _firestore.collection('job_orders').get();
      
      // Count active and completed job orders per customer
      Map<String, Map<String, int>> customerJobOrders = {};
      
      for (var doc in jobOrders.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        String customerId = data != null ? (data['customerId'] ?? '') : '';
        String status = data != null ? (data['status'] ?? '') : '';
            
        if (customerId.isNotEmpty) {
          customerJobOrders[customerId] ??= {'active': 0, 'completed': 0};
          if (status == 'completed') {
            customerJobOrders[customerId]!['completed'] = 
                (customerJobOrders[customerId]!['completed'] ?? 0) + 1;
          } else {
            customerJobOrders[customerId]!['active'] = 
                (customerJobOrders[customerId]!['active'] ?? 0) + 1;
          }
        }
      }
      
      // Calculate totals
      int totalActive = 0;
      int totalCompleted = 0;
      
      for (var counts in customerJobOrders.values) {
        totalActive += counts['active'] ?? 0;
        totalCompleted += counts['completed'] ?? 0;
      }
      
      result['total_customers'] = customers.size;
      result['active_job_orders'] = totalActive;
      result['completed_job_orders'] = totalCompleted;
      
      return result;
    } catch (e) {
      print('Error getting customers with job orders count: $e');
      return {
        'total_customers': 0,
        'active_job_orders': 0,
        'completed_job_orders': 0,
      };
    }
  }

  // Search customers
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      if (query.isEmpty) {
        QuerySnapshot snapshot = await _firestore
            .collection(_collectionName)
            .orderBy('createdAt', descending: true)
            .get();
        return snapshot.docs
            .map((doc) => Customer.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      }

      // Search by full name (case insensitive)
      QuerySnapshot snapshot = await _firestore
          .collection(_collectionName)
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return snapshot.docs
          .map((doc) => Customer.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    }
  }
}
