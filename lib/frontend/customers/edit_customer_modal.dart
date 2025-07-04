import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';

class EditCustomerModal extends StatefulWidget {
  final Customer customer;
  final VoidCallback? onCustomerUpdated;

  const EditCustomerModal({
    Key? key,
    required this.customer,
    this.onCustomerUpdated,
  }) : super(key: key);

  @override
  State<EditCustomerModal> createState() => _EditCustomerModalState();
}

class _EditCustomerModalState extends State<EditCustomerModal> {
  final _formKey = GlobalKey<FormState>();
  final CustomerService _customerService = CustomerService();
  final ScrollController _scrollController = ScrollController();
  
  late TextEditingController _fullNameController;
  late TextEditingController _contactController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _contactFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    _fullNameController = TextEditingController(text: widget.customer.fullName);
    _contactController = TextEditingController(text: widget.customer.contactNum);
    _emailController = TextEditingController(text: widget.customer.email ?? '');
    _addressController = TextEditingController(text: widget.customer.address ?? '');
    _notesController = TextEditingController(text: widget.customer.notes ?? '');
    
    // Add listener to automatically scroll when notes field is focused
    _notesFocus.addListener(() {
      if (_notesFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    });
    
    // Add listener to scroll when address field is focused
    _addressFocus.addListener(() {
      if (_addressFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.7,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    _fullNameFocus.dispose();
    _contactFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final updatedCustomer = Customer(
        id: widget.customer.id,
        fullName: _fullNameController.text.trim(),
        contactNum: _contactController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdBy: widget.customer.createdBy,
        createdAt: widget.customer.createdAt,
      );

      final success = await _customerService.updateCustomer(widget.customer.id, updatedCustomer);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('${updatedCustomer.fullName} updated successfully'),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          Navigator.pop(context, true);
          widget.onCustomerUpdated?.call();
        }
      } else {
        throw Exception('Failed to update customer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Failed to update customer: ${e.toString()}'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.pink[100]!, Colors.pink[200]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.pink[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Customer',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Update ${widget.customer.fullName}\'s information',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 100,
                  ),
                  child: Column(
                    children: [
                  // Full Name
                  Card(
                    elevation: 2,
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
                              Text(
                                'Full Name',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fullNameController,
                            focusNode: _fullNameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _contactFocus.requestFocus(),
                            decoration: InputDecoration(
                              hintText: 'Enter customer full name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.pink.shade400, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              if (value.trim().length < 2) {
                                return 'Full name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Number
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _contactController,
                            focusNode: _contactFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter phone number (e.g., +1234567890)',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.pink.shade400, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                // Remove all non-digit characters for validation
                                String cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                                
                                // Check if it's a valid mobile number format
                                if (cleanedValue.length < 10 || cleanedValue.length > 15) {
                                  return 'Phone number must be between 10-15 digits';
                                }
                                
                                // Check for valid mobile number patterns
                                if (!RegExp(r'^(\+?1)?[6-9]\d{9}$|^\+?[1-9]\d{7,14}$').hasMatch(cleanedValue)) {
                                  return 'Please enter a valid mobile number';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _addressFocus.requestFocus(),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Enter email address (optional)',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.pink.shade400, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                // More comprehensive email validation
                                String email = value.trim().toLowerCase();
                                
                                // Check basic email format
                                if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
                                  return 'Please enter a valid email address';
                                }
                                
                                // Check for common invalid patterns
                                if (email.startsWith('.') || email.endsWith('.') || 
                                    email.contains('..') || email.contains('@.') || 
                                    email.contains('.@')) {
                                  return 'Please enter a valid email address';
                                }
                                
                                // Check minimum length
                                if (email.length < 5) {
                                  return 'Email address is too short';
                                }
                                
                                // Check maximum length
                                if (email.length > 254) {
                                  return 'Email address is too long';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Address
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressController,
                            focusNode: _addressFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _notesFocus.requestFocus(),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter customer address (optional)',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.pink.shade400, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            focusNode: _notesFocus,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            maxLength: 200,
                            decoration: InputDecoration(
                              hintText: 'Any additional notes about this customer...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.pink.shade400, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitForm,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isLoading ? 'Updating...' : 'Update Customer',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                    ],
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
