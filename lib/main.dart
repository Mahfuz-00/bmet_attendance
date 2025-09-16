import 'dart:io';
import 'package:flutter/material.dart';
import 'Common/Config/Theme/app_colors.dart';
import 'Core/Dependecy Injection/di.dart' as di;
import 'Core/Navigation/app_router.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  di.init(); // Initialize dependency injection
  runApp(const TouchAttendanceApp());
}

class TouchAttendanceApp extends StatelessWidget {
  const TouchAttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Touch Attendance',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splashScreen,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}