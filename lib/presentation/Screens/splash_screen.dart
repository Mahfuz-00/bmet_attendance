import 'package:flutter/material.dart';
import 'dart:async';

import '../../Core/Core/Navigation/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      // Check login status (replace with your actual authentication logic)
      bool isLoggedIn = checkUserLoginStatus(); // Implement this function

      // Navigate based on login status
      String route = isLoggedIn ? AppRoutes.qrScanner : AppRoutes.login;
      Navigator.pushNamed(context, route);
    });
  }

  // Example function to check login status (replace with actual logic)
  bool checkUserLoginStatus() {
    // Placeholder: Implement your authentication check here
    // For example, check SharedPreferences, Firebase Auth, or another auth service
    // Return true if user is logged in, false otherwise
    return false; // Default to false for demonstration
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Touch Automatic Attendance System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}