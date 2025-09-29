import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';
import '../Bloc/face_recognition_bloc.dart';
import '../Widgets/camera_preview_widget.dart';
import '../Widgets/cancel_button_widget.dart';
import '../Widgets/capture_button_widget.dart';
import '../Widgets/profile_image_preview_widget.dart';
import '../Widgets/submit_button_widget.dart';
import '../Widgets/action_button_widget.dart';
import '../../Core/Navigation/app_router.dart';

class AttendancePhotoScreen extends StatefulWidget {
  const AttendancePhotoScreen({Key? key}) : super(key: key);

  @override
  _AttendancePhotoScreenState createState() => _AttendancePhotoScreenState();
}

class _AttendancePhotoScreenState extends State<AttendancePhotoScreen> {
  bool _showProfileImage = true;
  bool _showProceedButton = false;
  bool _hasFetchedEmbedding = false;
  Timer? _timer;
  CameraController? _controller;
  String? _cameraError;
  ValueNotifier<bool> _isProcessingNotifier = ValueNotifier(false);
  ValueNotifier<bool> _isFaceProperNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    // Start 5-second timer for "Proceed to Capture"
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showProceedButton = true;
        });
      }
    });
    // Fetch embedding once
    Future.microtask(() {
      final dataState = context.read<AttendanceDataBloc>().state;
      final regState = context.read<RegistrationBloc>().state;
      final isRegistered = regState is RegistrationLoaded && regState.status == 'Register';
      if (dataState is AttendanceDataLoaded && isRegistered) {
        final studentId = dataState.student.fields['Student ID'] ?? '';
        if (studentId.isNotEmpty && !_hasFetchedEmbedding) {
          _hasFetchedEmbedding = true;
          print('AttendancePhotoScreen: Fetching face embedding for studentId: $studentId');
          context.read<FaceRecognitionBloc>().add(FetchFaceEmbeddingEvent(studentId));
        } else if (studentId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student ID is missing')),
          );
        }
      }
    });
    // Initialize camera with delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _initializeCamera();
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      print('AttendancePhotoScreen: Initializing camera');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No cameras available on this device';
        });
        print('AttendancePhotoScreen: No cameras available');
        return;
      }
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      print('AttendancePhotoScreen: Camera selected, lensDirection: ${frontCamera.lensDirection}, name: ${frontCamera.name}');
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _controller!.initialize();
      print('AttendancePhotoScreen: Camera initialized successfully');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _cameraError = 'Failed to initialize camera. Please try again or restart the app.';
      });
      print('AttendancePhotoScreen: Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    print('AttendancePhotoScreen: Disposing timer and camera');
    _timer?.cancel();
    _controller?.dispose();
    _isProcessingNotifier.dispose();
    _isFaceProperNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return BlocListener<FaceRecognitionBloc, FaceRecognitionState>(
      listener: (context, faceState) {
        if (faceState is FaceRecognitionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch face data. Please try capturing the photo.')),
          );
          _isProcessingNotifier.value = false;
        } else if (faceState is FaceRecognitionVerified && !faceState.isMatch) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face does not match registered student')),
          );
          _isProcessingNotifier.value = false;
        } else if (faceState is FaceRecognitionLoading) {
          _isProcessingNotifier.value = true;
        } else {
          _isProcessingNotifier.value = false;
        }
        // TODO: Replace with actual face detection logic
        _isFaceProperNotifier.value = false; // Placeholder until face detection is integrated
      },
      child: BlocBuilder<RegistrationBloc, RegistrationState>(
        builder: (context, regState) {
          final isRegistered = regState is RegistrationLoaded && regState.status == 'Register';
          return BlocBuilder<AttendanceDataBloc, AttendanceDataState>(
            builder: (context, dataState) {
              if (dataState is! AttendanceDataLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              final student = dataState.student;
              return Scaffold(
                appBar: AppBar(
                  title: Text(isRegistered ? 'Take Attendance' : 'Register Student'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Back to QR Scanner',
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.qrScanner,
                              (route) => false,
                        );
                      },
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    if (isRegistered && _showProfileImage) ...[
                      Expanded(
                        child: Center(
                          child: Container(
                            alignment: Alignment.center,
                            width: screenWidth * 0.9,
                            child: ProfileImagePreviewWidget(
                              profileImages: student.profileImages,
                              width: screenWidth * 0.9,
                            ),
                          ),
                        ),
                      ),
                      if (_showProceedButton)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Center(
                            child: ActionButtonWidget(
                              label: 'Proceed to Capture',
                              icon: Icons.camera_alt,
                              isLoading: false,
                              width: screenWidth * 0.9,
                              onPressed: () {
                                setState(() {
                                  _showProfileImage = false;
                                  _showProceedButton = false;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                    if (!isRegistered || !_showProfileImage) ...[
                      Expanded(
                        child: Stack(
                          children: [
                            if (_cameraError != null)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _cameraError!,
                                      style: const TextStyle(color: Colors.red, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _cameraError = null;
                                        });
                                        _initializeCamera();
                                      },
                                      child: const Text('Retry Camera'),
                                    ),
                                  ],
                                ),
                              )
                            else if (_controller == null || !_controller!.value.isInitialized)
                              const Center(child: CircularProgressIndicator())
                            else
                              CameraPreviewWidget(
                                controller: _controller!,
                                isProcessingNotifier: _isProcessingNotifier,
                                isFaceProperNotifier: _isFaceProperNotifier,
                              ),
                            Positioned(
                              top: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'Capture Face',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: SubmitButtonWidget(
                                student: student,
                                isRegistered: isRegistered,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: const CancelButtonWidget(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}