import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../Common/Config/Assets/app_images.dart';
import '../../Common/Config/Theme/app_colors.dart';
import '../../Core/Navigation/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      print('SplashScreen: isLoggedIn: $isLoggedIn');

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          isLoggedIn ? AppRoutes.enrollmentImage : AppRoutes.login,
              (route) => false,
        );
      }
    });
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
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image,
                  size: 100,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
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