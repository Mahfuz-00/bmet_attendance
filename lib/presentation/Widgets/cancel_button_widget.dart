import 'package:flutter/material.dart';
import '../../Core/Navigation/app_router.dart';

class CancelButtonWidget extends StatelessWidget {
  const CancelButtonWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 100), // Match height: 30
        backgroundColor: Colors.red,
      ),
      onPressed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.qrScanner,
              (route) => false,
        );
      },
      child: const Text('Cancel'),
    );
  }
}