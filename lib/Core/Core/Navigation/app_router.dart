import 'package:flutter/material.dart';

import '../../../presentation/Screens/log_in.dart';
import '../../../presentation/Screens/qrscanner.dart';
import '../../../presentation/Screens/splash_screen.dart';
import '../../../presentation/Screens/text_display.dart';

class AppRoutes {
  static const String login = '/login';
  static const String qrScanner = '/qr-scanner';
  static const String splashScreen = '/splash-screen';
  static const String textDisplay = '/text-display';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case qrScanner:
        return MaterialPageRoute(builder: (_) => const QRScannerScreen());
      case splashScreen:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case textDisplay:
      // Extract arguments from settings
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => TextDisplayScreen(
            text: args?['text'] ?? '',
            images: args?['images'] ?? [],
            imageTexts: args?['imageTexts'] ?? [],
            profileDetections: args?['profileDetections'] ?? [],
            profileImages: args?['profileImages'] ?? [],
            extractedFields: args?['extractedFields'] ?? {},
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}