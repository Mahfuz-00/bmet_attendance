import 'package:flutter/material.dart';
import '../../Core/Navigation/app_router.dart';
import '../Widgets/action_button_widget.dart';

class CancelButtonWidget extends StatelessWidget {
  const CancelButtonWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ActionButtonWidget(
      label: 'Cancel',
      icon: Icons.close,
      backgroundColor: Colors.red,
      onPressed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.qrScanner,
              (route) => false,
        );
      },
    );
  }
}