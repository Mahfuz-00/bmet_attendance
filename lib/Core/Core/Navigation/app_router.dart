import 'package:flutter/material.dart';
import '../../../presentation/Screens/attendance_photo.dart';
import '../../../presentation/Screens/log_in.dart';
import '../../../presentation/Screens/qrscanner.dart';
import '../../../presentation/Screens/splash_screen.dart';
import '../../../presentation/Screens/text_display.dart';

class AppRoutes {
  static const String login = '/login';
  static const String qrScanner = '/qr-scanner';
  static const String splashScreen = '/splash-screen';
  static const String textDisplay = '/text-display';
  static const String attendancePhoto = '/attendance-photo'; // Fixed camelCase for consistency

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case qrScanner:
        return MaterialPageRoute(builder: (_) => const QRScannerScreen());
      case splashScreen:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case textDisplay:
        return MaterialPageRoute(builder: (_) => const TextDisplayScreen());
      case attendancePhoto:
        return MaterialPageRoute(builder: (_) => const AttendancePhotoScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}