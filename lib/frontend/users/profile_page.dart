import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('No user logged in.'))
          : FutureBuilder<Map<String, dynamic>?>(
              future: _fetchUserData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userData = snapshot.data;
                if (userData == null) {
                  return const Center(child: Text('User data not found.'));
                }
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
                    child: Column(
                      children: [
                        // Avatar
                        user.photoURL != null
                            ? CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.teal.shade100,
                                backgroundImage: NetworkImage(user.photoURL!),
                              )
                            : CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.teal,
                                child: Text(
                                  (userData['fullname'] != null && userData['fullname'].toString().isNotEmpty)
                                      ? userData['fullname'].toString().trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                      : (user.email != null && user.email!.isNotEmpty)
                                          ? user.email![0].toUpperCase()
                                          : 'U',
                                  style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                        const SizedBox(height: 10),
                        Text(
                          userData['fullname'] ?? 'No Name',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2),
                        ),
                        if (userData['username'] != null && userData['username'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              '@${userData['username']}',
                              style: const TextStyle(fontSize: 14, color: Colors.teal, height: 1.2),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 1,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              children: [
                                _profileRow(Icons.email, user.email ?? 'No Email'),
                                _profileRow(Icons.verified_user, 'Role: ${userData['role'] ?? 'N/A'}'),
                                _profileRow(Icons.check_circle, 'Active: ${userData['isActive'] == true ? "Yes" : "No"}'),
                                _profileRow(
                                  Icons.calendar_today,
                                  'Joined: ${userData['createdAt'] != null && userData['createdAt'] is Timestamp
                                      ? (userData['createdAt'] as Timestamp).toDate().toString().split('.').first
                                      : 'Unknown'}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
  Widget _profileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}