import 'package:flutter/material.dart';
import 'package:touch_attendence/presentation/Screens/splash_screen.dart';

void main() {
  runApp(const TouchAttendanceApp());
}

class TouchAttendanceApp extends StatelessWidget {
  const TouchAttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touch Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}