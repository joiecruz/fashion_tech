import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_dashboard.dart';
import 'inventory_page.dart';
import 'job_page.dart';
import '../backend/login_be.dart';
import 'users/profile_page.dart';
import 'users/settings_page.dart'; // <-- Make sure this import is present
import 'notifications/notification_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  String _inventorySubtab = 'Products';
  String _jobSubtab = 'Orders';

  final List<String> _titles = [
    'Home',
    'Inventory',
    'Job',
  ];

  void _onInventoryTabChanged(String subtab) {
    setState(() {
      _inventorySubtab = subtab;
    });
  }

  void _onJobTabChanged(String subtab) {
    setState(() {
      _jobSubtab = subtab;
    });
  }

  String get _currentTitle {
    if (_selectedIndex == 1) {
      return 'Inventory | $_inventorySubtab';
    } else if (_selectedIndex == 2) {
      return 'Job | $_jobSubtab';
    }
    return _titles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeDashboard(),
      InventoryPage(onTabChanged: _onInventoryTabChanged),
      JobPage(onTabChanged: _onJobTabChanged),
    ];

    // Fetch current user for avatar and profile
    final user = FirebaseAuth.instance.currentUser;
    final String? photoUrl = user?.photoURL;
    final String initials = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : (user?.email != null && user!.email!.isNotEmpty)
            ? user.email![0].toUpperCase()
            : 'U';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              isScrollControlled: true,
              builder: (context) => const NotificationsModal(),
            );
          },
        ),
        title: Text(
          _currentTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 40), // Position dropdown below the icon
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              } else if (value == 'logout') {
                await LoginBackend.signOut();
                // AuthWrapper will handle redirect to login
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, size: 18),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: photoUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(photoUrl),
                      backgroundColor: Colors.grey[200],
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.black54,
        selectedIconTheme: const IconThemeData(color: Colors.teal),
        unselectedIconTheme: const IconThemeData(color: Colors.black54),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Job'),
        ],
      ),
    );
  }
}