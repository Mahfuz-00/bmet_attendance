import 'package:flutter/material.dart';
import 'package:touch_attendence/Common/Common/Config/Theme/app_colors.dart';
import 'dart:async';

import '../../Common/Common/Config/Assets/app_images.dart';
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
      // bool isLoggedIn = checkUserLoginStatus(); // Implement this function

      // Navigate based on login status
      // String route = isLoggedIn ? AppRoutes.qrScanner : AppRoutes.login;
      Navigator.pushNamed(context, AppRoutes.qrScanner);
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
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AppImages.loginLogo,
                height: 100,
                width: 100,
              ),
              SizedBox(height: 16,),
              const Text(
                'Touch Smart Attendance System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}