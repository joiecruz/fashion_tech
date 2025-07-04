import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/job_order.dart';
import '../../services/job_order_service.dart';
import '../../services/customer_service.dart';
import '../job_orders/add_job_order_modal.dart';
import 'edit_customer_modal.dart';

class CustomerDetailPage extends StatefulWidget {
  final Customer customer;

  const CustomerDetailPage({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final JobOrderService _jobOrderService = JobOrderService();
  final CustomerService _customerService = CustomerService();
  List<JobOrder> _jobOrders = [];
  bool _isLoadingJobOrders = true;

  @override
  void initState() {
    super.initState();
    _loadJobOrders();
  }

  Future<void> _loadJobOrders() async {
    setState(() {
      _isLoadingJobOrders = true;
    });

    try {
      final jobOrders = await _jobOrderService.getJobOrdersByCustomer(widget.customer.id);
      setState(() {
        _jobOrders = jobOrders;
        _isLoadingJobOrders = false;
      });
    } catch (e) {
      print('Error loading job orders: $e');
      setState(() {
        _isLoadingJobOrders = false;
      });
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${widget.customer.fullName}?\n\nThis action cannot be undone and will also delete all associated job orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red[50],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await _customerService.deleteCustomer(widget.customer.id);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('${widget.customer.fullName} deleted successfully'),
                  ],
                ),
                backgroundColor: Colors.green[600],
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
            Navigator.pop(context, true); // Return true to indicate customer was deleted
          }
        } else {
          throw Exception('Failed to delete customer');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Failed to delete customer: ${e.toString()}'),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  void _editCustomer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 100),
        height: MediaQuery.of(context).size.height - 100,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: EditCustomerModal(
          customer: widget.customer,
          onCustomerUpdated: () {
            // Refresh the page by popping and returning updated flag
            Navigator.pop(context, true);
          },
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Customer was updated, pop this page to refresh the list
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.customer.fullName,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.grey[800]),
            onPressed: _editCustomer,
            tooltip: 'Edit Customer',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red[600]),
            onPressed: _deleteCustomer,
            tooltip: 'Delete Customer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Customer Info Card
            Container(
              margin: const EdgeInsets.all(20),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.pink[100]!, Colors.pink[200]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.pink[700],
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.customer.fullName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Customer Details',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Customer details
                      _buildDetailRow(
                        Icons.phone,
                        'Contact Number',
                        widget.customer.contactNum.isNotEmpty ? widget.customer.contactNum : 'Not provided',
                      ),
                      
                      if (widget.customer.email != null && widget.customer.email!.isNotEmpty)
                        _buildDetailRow(
                          Icons.email,
                          'Email',
                          widget.customer.email!,
                        ),
                      
                      if (widget.customer.address != null && widget.customer.address!.isNotEmpty)
                        _buildDetailRow(
                          Icons.location_on,
                          'Address',
                          widget.customer.address!,
                        ),
                      
                      if (widget.customer.notes != null && widget.customer.notes!.isNotEmpty)
                        _buildDetailRow(
                          Icons.note,
                          'Notes',
                          widget.customer.notes!,
                        ),
                      
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Customer Since',
                        '${widget.customer.createdAt.day}/${widget.customer.createdAt.month}/${widget.customer.createdAt.year}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Job Orders Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.work,
                            color: Colors.pink[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Job Orders',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _showAddJobOrderModal(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Job Orders List
                      _isLoadingJobOrders
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _jobOrders.isEmpty
                              ? _buildEmptyJobOrders()
                              : Column(
                                  children: _jobOrders.map((jobOrder) => _buildJobOrderCard(jobOrder)).toList(),
                                ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.pink[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJobOrders() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.work_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No job orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the "New" button above to create the first job order',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobOrderCard(JobOrder jobOrder) {
    Color statusColor = _getStatusColor(jobOrder.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      jobOrder.id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(jobOrder.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                jobOrder.name,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${jobOrder.createdAt.day}/${jobOrder.createdAt.month}/${jobOrder.createdAt.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.shopping_cart, size: 14, color: Colors.grey[500]),
                  Text(
                    'Qty: ${jobOrder.quantity}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(JobOrderStatus status) {
    switch (status) {
      case JobOrderStatus.open:
        return Colors.orange;
      case JobOrderStatus.inProgress:
        return Colors.blue;
      case JobOrderStatus.done:
        return Colors.green;
    }
  }

  String _getStatusText(JobOrderStatus status) {
    switch (status) {
      case JobOrderStatus.open:
        return 'OPEN';
      case JobOrderStatus.inProgress:
        return 'IN PROGRESS';
      case JobOrderStatus.done:
        return 'DONE';
    }
  }

  void _showAddJobOrderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddJobOrderModal(),
    ).then((_) => _loadJobOrders());
  }
}
