import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotifPresModal extends StatefulWidget {
  const NotifPresModal({Key? key}) : super(key: key);

  @override
  State<NotifPresModal> createState() => _NotifPresModalState();
}

class _NotifPresModalState extends State<NotifPresModal> {
  bool _jobDue = true;
  bool _lowStock = true;
  bool _outOfStock = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['notifPrefs'] != null) {
      final prefs = data['notifPrefs'] as Map<String, dynamic>;
      _jobDue = prefs['jobDue'] ?? true;
      _lowStock = prefs['lowStock'] ?? true;
      _outOfStock = prefs['outOfStock'] ?? true;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _savePrefs() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'notifPrefs': {
        'jobDue': _jobDue,
        'lowStock': _lowStock,
        'outOfStock': _outOfStock,
      }
    });
    setState(() => _isLoading = false);
    if (mounted) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification preferences updated!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Material(
        color: Colors.transparent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    value: _jobDue,
                    onChanged: (v) => setState(() => _jobDue = v),
                    title: const Text('Job Order Due Soon'),
                    subtitle: const Text('Get notified when a job order is due soon.'),
                    secondary: const Icon(Icons.event),
                  ),
                  SwitchListTile(
                    value: _lowStock,
                    onChanged: (v) => setState(() => _lowStock = v),
                    title: const Text('Low Stock'),
                    subtitle: const Text('Get notified when a product is low on stock.'),
                    secondary: const Icon(Icons.warning),
                  ),
                  SwitchListTile(
                    value: _outOfStock,
                    onChanged: (v) => setState(() => _outOfStock = v),
                    title: const Text('Out of Stock'),
                    subtitle: const Text('Get notified when a product is out of stock.'),
                    secondary: const Icon(Icons.error),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'Save Preferences'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _savePrefs,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
      ),
    );
  }
}