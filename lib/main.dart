import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'backend/firebase_options.dart';
import 'frontend/main_scaffold.dart';
import 'frontend/auth/login_page.dart';
import 'frontend/admin/admin_home_page.dart';
import 'services/user_service.dart';
import 'services/color_service.dart';
import 'utils/color_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize default colors in the background
  ColorService.initializeDefaultColors().catchError((error) {
    print('[INFO] Colors may need manual initialization: $error');
  });
  
  // Initialize ColorUtils with database colors
  ColorUtils.initializeColors().catchError((error) {
    print('[INFO] ColorUtils will use fallback colors: $error');
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Tech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure login page is shown first
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always show login page initially
    if (!_isInitialized) {
      return const LoginPage();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoginPage(); // Show login page instead of loading spinner
        }
        
        // If user is logged in, check their role
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<bool>(
            future: UserService.isCurrentUserAdmin(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // Show admin page if user is admin, otherwise show main scaffold
              if (roleSnapshot.data == true) {
                return const AdminHomePage();
              } else {
                return const MainScaffold();
              }
            },
          );
        }
        
        // Default: show login page (when not logged in or no data)
        return const LoginPage();
      },
    );
  }
}