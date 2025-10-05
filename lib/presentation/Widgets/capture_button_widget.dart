import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'dart:typed_data';
import '../Bloc/face_recognition_bloc.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';

class CaptureButtonWidget extends StatefulWidget {
  final CameraController? controller;
  final bool isProcessing;
  final ValueNotifier<bool> isFaceProperNotifier;
  final Function(Uint8List?) onCapture;

  const CaptureButtonWidget({
    Key? key,
    required this.controller,
    required this.isProcessing,
    required this.isFaceProperNotifier,
    required this.onCapture,
  }) : super(key: key);

  @override
  _CaptureButtonWidgetState createState() => _CaptureButtonWidgetState();
}

class _CaptureButtonWidgetState extends State<CaptureButtonWidget> {
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isFaceProperNotifier,
      builder: (context, isFaceProper, _) {
        final isEnabled = !widget.isProcessing &&
            !_isCapturing &&
            isFaceProper &&
            widget.controller != null &&
            widget.controller!.value.isInitialized;
        print(
            'CaptureButtonWidget: isEnabled=$isEnabled, isProcessing=${widget.isProcessing}, isCapturing=$_isCapturing, isFaceProper=$isFaceProper, controllerInitialized=${widget.controller?.value.isInitialized}');
        return Stack(
          alignment: Alignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 30),
              ),
              onPressed: isEnabled
                  ? () async {
                if (_isCapturing) return;
                setState(() {
                  _isCapturing = true;
                });
                try {
                  print('CaptureButtonWidget: Starting capture');
                  await widget.controller!.setFocusPoint(const Offset(0.5, 0.5));
                  await widget.controller!.setFocusMode(FocusMode.locked);
                  final shot = await widget.controller!.takePicture();
                  final bytes = await shot.readAsBytes();
                  await widget.controller!.setFocusMode(FocusMode.auto);
                  print('CaptureButtonWidget: Captured image of size: ${bytes.length} bytes');
                  widget.onCapture(bytes);
                  final regState = context.read<RegistrationBloc>().state;
                  final dataState = context.read<AttendanceDataBloc>().state;
                  final isRegistered = regState is RegistrationLoaded && regState.status == 'Register';
                  final studentId = dataState is AttendanceDataLoaded ? dataState.student.fields['Student ID'] : null;
                  context.read<FaceRecognitionBloc>().add(CaptureFaceImage(
                    bytes,
                    isRegistered: isRegistered,
                    studentId: studentId,
                  ));
                } catch (e) {
                  print('CaptureButtonWidget: Capture error: $e');
                  widget.onCapture(null);
                  // Do not show snackbar here; handle in parent widget
                } finally {
                  if (mounted) {
                    setState(() {
                      _isCapturing = false;
                    });
                  }
                  print('CaptureButtonWidget: Capture state reset, isCapturing=$_isCapturing');
                }
              }
                  : null,
              child: const Text('Capture'),
            ),
            if (_isCapturing)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }
}