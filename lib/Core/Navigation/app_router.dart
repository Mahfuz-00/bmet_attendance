import 'package:flutter/material.dart';
import '../../Presentation/Screens/attendance_photo.dart';
import '../../Presentation/Screens/log_in.dart';
import '../../Presentation/Screens/qrscanner.dart';
import '../../Presentation/Screens/splash_screen.dart';
import '../../Presentation/Screens/text_display.dart';

class AppRoutes {
  static const String login = '/login';
  static const String qrScanner = '/qr-scanner';
  static const String splashScreen = '/splash-screen';
  static const String textDisplay = '/text-display';
  static const String attendancePhoto = '/attendance-photo';
  static const String enrollmentImage = '/enrollment-image';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    Widget screen;

    switch (settings.name) {
      case login:
        screen = const LoginPage();
        break;
      case qrScanner:
        screen = const QRScannerScreen();
        break;
      case splashScreen:
        screen = const SplashScreen();
        break;
      case textDisplay:
        screen = const TextDisplayScreen();
        break;
      case attendancePhoto:
        screen = const AttendancePhotoScreen();
        break;
      default:
        screen = const Scaffold(
          body: Center(child: Text('Page not found')),
        );
    }

    return MaterialPageRoute(
      builder: (context) => screen,
      settings: settings,
    );
  }
}
