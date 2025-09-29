import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Core/Dependecy Injection/di.dart';
import '../../Core/Navigation/app_router.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Widgets/pdf_fetcher_widget.dart';
import '../Widgets/qr_scanner_ui_widget.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceDataBloc>();

    return QRScannerUI(
      isProcessing: isProcessing,
      onQRScanned: (url) async {
        if (isProcessing) return;
        setState(() {
          isProcessing = true;
        });
        try {
          print('QRScanner: Scanned URL: $url');
          final result = await PdfFetcher.processPdf(url);
          print('QRScanner: Extracted ${result.profileImages.length} images');
          // Defer BLoC access to ensure context is ready
          await Future.microtask(() {
            try {
              bloc.add(SetAttendanceData(
                fields: result.extractedFields,
                profileImages: result.profileImages,
              ));
              print('QRScanner: Navigating to textDisplay');
              Navigator.pushNamed(context, AppRoutes.textDisplay);
            } catch (e) {
              print('QRScanner: BLoC access error: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('BLoC error: $e')),
              );
            }
          });
        } catch (e) {
          print('QRScanner: Error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        } finally {
          setState(() {
            isProcessing = false;
          });
        }
      },
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.setBool('is_logged_in', false);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
              (route) => false,
        );
      },
    );
  }
}