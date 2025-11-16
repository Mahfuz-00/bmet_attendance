import 'package:flutter/material.dart';
import '../../Core/Navigation/app_router.dart';

class CancelButtonWidget extends StatelessWidget {
  const CancelButtonWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,  // fixed width
      height: 80, // fixed height
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
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
      ),
    );
  }
}