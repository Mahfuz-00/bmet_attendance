import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:touch_attendence/Common/Common/Config/Theme/app_colors.dart';
import 'package:touch_attendence/presentation/State%20Management/attendance_data_provider.dart';

import 'Core/Core/Navigation/app_router.dart';

import 'package:http/http.dart' as http;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const TouchAttendanceApp());
}

class TouchAttendanceApp extends StatelessWidget {
  const TouchAttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceDataProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Touch Attendance',
        theme: ThemeData(
          primaryColor: AppColors.primary,
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.splashScreen, // Set the initial route
        onGenerateRoute: AppRoutes.generateRoute, // Use AppRoutes for navigation
      ),
    );
  }
}