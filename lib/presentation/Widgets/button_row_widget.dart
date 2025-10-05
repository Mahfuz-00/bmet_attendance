import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import '../../Domain/Entities/student.dart';
import '../Widgets/capture_button_widget.dart';
import '../Widgets/cancel_button_widget.dart';
import '../Widgets/submit_button_widget.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';

class ButtonRowWidget extends StatelessWidget {
  final CameraController? controller;
  final bool isProcessing;
  final ValueNotifier<bool> isFaceProperNotifier;
  final Function(Uint8List?) onCapture;
  final bool showSubmitButton;
  final Student? student;
  final bool isRegistered;

  const ButtonRowWidget({
    Key? key,
    required this.controller,
    required this.isProcessing,
    required this.isFaceProperNotifier,
    required this.onCapture,
    required this.showSubmitButton,
    required this.student,
    required this.isRegistered,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (showSubmitButton && student != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SubmitButtonWidget(
          student: student!,
          isRegistered: isRegistered,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: screenWidth * 0.35,
            height: 50,
            child: CaptureButtonWidget(
              controller: controller,
              isProcessing: isProcessing,
              isFaceProperNotifier: isFaceProperNotifier,
              onCapture: onCapture,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: screenWidth * 0.35,
            height: 50,
            child: const CancelButtonWidget(),
          ),
        ],
      ),
    );
  }
}