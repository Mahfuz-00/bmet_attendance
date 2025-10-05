import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';
import '../Bloc/face_recognition_bloc.dart';
import '../Widgets/camera_preview_widget.dart';
import '../Widgets/button_row_widget.dart';
import '../Widgets/profile_image_widget.dart';
import '../Widgets/action_button_widget.dart';
import '../Widgets/submit_button_widget.dart';
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
  bool _showSubmitButton = false;
  Timer? _timer;
  Timer? _faceCheckTimer;
  CameraController? _controller;
  String? _cameraError;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _runFaceSizeCheck = true;
  bool? _lastFaceProperState;
  DateTime? _lastFaceUpdate;
  final ValueNotifier<bool> _isProcessingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isFaceProperNotifier = ValueNotifier(false);
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast, // Use fast mode to reduce load
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showProceedButton = true;
        });
      }
    });
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
      _initializeCamera();
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
      final backCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      print('AttendancePhotoScreen: Camera selected, lensDirection: ${backCamera.lensDirection}, name: ${backCamera.name}');
      if (_controller != null) {
        await _controller!.dispose();
        print('AttendancePhotoScreen: Disposed existing camera controller');
      }
      _controller = CameraController(
        backCamera,
        ResolutionPreset.low, // Further reduced resolution
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      print('AttendancePhotoScreen: Starting camera initialization');
      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setFocusPoint(const Offset(0.5, 0.5));
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposureOffset(0.2);
      print('AttendancePhotoScreen: Camera initialized successfully');
      if (mounted) {
        setState(() {});
        _startFaceSizeCheck();
      }
    } catch (e, stackTrace) {
      setState(() {
        _cameraError = 'Failed to initialize camera: $e';
      });
      print('AttendancePhotoScreen: Error initializing camera: $e, stackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    }
  }

  Future<Uint8List?> _captureJpegBytes({bool silent = false}) async {
    if (_isCapturing) {
      if (!silent) {
        print('AttendancePhotoScreen: Capture skipped: another capture in progress');
      }
      return null;
    }
    try {
      _isCapturing = true;
      if (_controller == null || !_controller!.value.isInitialized) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera not ready')),
          );
        }
        print('AttendancePhotoScreen: Capture skipped: camera not ready');
        return null;
      }
      await _controller!.setFocusPoint(const Offset(0.5, 0.5));
      await _controller!.setFocusMode(FocusMode.locked);
      final shot = await _controller!.takePicture();
      final bytes = await shot.readAsBytes();
      await _controller!.setFocusMode(FocusMode.auto);
      if (!silent) {
        print('AttendancePhotoScreen: Captured image of size: ${bytes.lengthInBytes} bytes');
      }
      return bytes;
    } catch (e, stackTrace) {
      if (!silent) {
        print('AttendancePhotoScreen: Capture error: $e, stackTrace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      }
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _startFaceSizeCheck() async {
    _runFaceSizeCheck = true;
    _faceCheckTimer?.cancel();
    _faceCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_runFaceSizeCheck || _isProcessing || _controller == null || !_controller!.value.isInitialized || _isCapturing) {
        print('AttendancePhotoScreen: Face check skipped: runFaceSizeCheck=$_runFaceSizeCheck, isProcessing=$_isProcessing, isCapturing=$_isCapturing');
        return;
      }
      try {
        final bytes = await _captureJpegBytes(silent: true);
        if (bytes != null) {
          final isProper = await _isFaceProperlySized(bytes);
          final now = DateTime.now();
          if (_lastFaceProperState != isProper || _lastFaceUpdate == null || now.difference(_lastFaceUpdate!).inMilliseconds >= 5000) {
            if (mounted) {
              _isFaceProperNotifier.value = isProper;
              _lastFaceProperState = isProper;
              _lastFaceUpdate = now;
              print('AttendancePhotoScreen: Face proper: $isProper, isProcessing: $_isProcessing, isCapturing: $_isCapturing');
            }
          }
        } else {
          if (_lastFaceProperState != false) {
            if (mounted) {
              _isFaceProperNotifier.value = false;
              _lastFaceProperState = false;
              _lastFaceUpdate = DateTime.now();
              print('AttendancePhotoScreen: No face detected: capture failed, isProcessing: $_isProcessing, isCapturing: $_isCapturing');
            }
          }
        }
      } catch (e, stackTrace) {
        print('AttendancePhotoScreen: Face size check error: $e, stackTrace: $stackTrace');
      }
    });
  }

  Future<bool> _isFaceProperlySized(Uint8List jpegBytes) async {
    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) {
        print('AttendancePhotoScreen: Failed to decode image for size check');
        return false;
      }
      final targetWidth = 320; // Further reduced resolution
      final targetHeight = (decoded.height * targetWidth / decoded.width).round();
      final preResized = img.copyResize(decoded, width: targetWidth, height: targetHeight);
      final preResizedBytes = img.encodeJpg(preResized, quality: 70); // Lower quality
      final tempFile = File('${Directory.systemTemp.path}/tmp_face_check_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(preResizedBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faces = await _faceDetector.processImage(inputImage);
      await tempFile.delete();
      if (faces.isEmpty) {
        print('AttendancePhotoScreen: No face detected for size check');
        return false;
      }
      final face = faces.first;
      final faceWidthPercent = face.boundingBox.width / preResized.width;
      print('AttendancePhotoScreen: Face size check: ${(faceWidthPercent * 100).toStringAsFixed(2)}%');
      return faceWidthPercent >= 0.15 && faceWidthPercent <= 0.5;
    } catch (e, stackTrace) {
      print('AttendancePhotoScreen: Face size check error: $e, stackTrace: $stackTrace');
      return false;
    }
  }

  void _pauseFaceSizeCheck() {
    print('AttendancePhotoScreen: Pausing face size check');
    _runFaceSizeCheck = false;
    _faceCheckTimer?.cancel();
  }

  void _resumeFaceSizeCheck() {
    print('AttendancePhotoScreen: Resuming face size check');
    _runFaceSizeCheck = true;
    _startFaceSizeCheck();
  }

  @override
  void dispose() {
    print('AttendancePhotoScreen: Disposing timer, camera, and face detector');
    _timer?.cancel();
    _faceCheckTimer?.cancel();
    _controller?.dispose();
    _faceDetector.close();
    _isProcessingNotifier.dispose();
    _isFaceProperNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return BlocListener<FaceRecognitionBloc, FaceRecognitionState>(
      listener: (context, faceState) {
        try {
          if (faceState is FaceRecognitionError) {
            print('AttendancePhotoScreen: FaceRecognitionError - isProcessing: $_isProcessing, isFaceProper: ${_isFaceProperNotifier.value}, isCapturing: $_isCapturing, message: ${faceState.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(faceState.message)),
            );
            _isProcessingNotifier.value = false;
            _isProcessing = false;
            _showSubmitButton = false; // Explicitly reset
            _resumeFaceSizeCheck();
          } else if (faceState is FaceRecognitionVerified && !faceState.isMatch) {
            print('AttendancePhotoScreen: FaceRecognitionVerified - no match, isProcessing: $_isProcessing, isFaceProper: ${_isFaceProperNotifier.value}, isCapturing: $_isCapturing');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face does not match registered student')),
            );
            _isProcessingNotifier.value = false;
            _isProcessing = false;
            _showSubmitButton = false; // Explicitly reset
            _resumeFaceSizeCheck();
          } else if (faceState is FaceRecognitionCaptured) {
            if (faceState.embedding.isEmpty || faceState.embedding.length != 512) {
              print('AttendancePhotoScreen: Invalid embedding in FaceRecognitionCaptured, length: ${faceState.embedding.length}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid face embedding captured')),
              );
              _isProcessingNotifier.value = false;
              _isProcessing = false;
              _showSubmitButton = false;
              _resumeFaceSizeCheck();
            } else {
              print('AttendancePhotoScreen: FaceRecognitionCaptured - isProcessing: $_isProcessing, isFaceProper: ${_isFaceProperNotifier.value}, isCapturing: $_isCapturing, showSubmitButton: ${faceState.showSubmitButton}');
              _isProcessingNotifier.value = false;
              _isProcessing = false;
              _showSubmitButton = faceState.showSubmitButton;
              _resumeFaceSizeCheck();
            }
          } else if (faceState is FaceRecognitionLoading) {
            print('AttendancePhotoScreen: FaceRecognitionLoading - isProcessing: $_isProcessing, isFaceProper: ${_isFaceProperNotifier.value}, isCapturing: $_isCapturing');
            _isProcessingNotifier.value = true;
            _isProcessing = true;
            _pauseFaceSizeCheck();
          } else {
            print('AttendancePhotoScreen: Other state (e.g., Initial, Fetched) - isProcessing: $_isProcessing, isFaceProper: ${_isFaceProperNotifier.value}, isCapturing: $_isCapturing');
            _isProcessingNotifier.value = false;
            _isProcessing = false;
            _showSubmitButton = false; // Explicitly reset
            _resumeFaceSizeCheck();
          }
        } catch (e, stackTrace) {
          print('AttendancePhotoScreen: Error in BlocListener: $e, stackTrace: $stackTrace');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unexpected error: $e')),
          );
          _showSubmitButton = false; // Reset on error
          _resumeFaceSizeCheck();
        }
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
                        flex: 2,
                        child: Center(
                          child: Container(
                            alignment: Alignment.center,
                            width: screenWidth * 0.9,
                            child: ProfileImageWidget(
                              profileImages: student.profileImages,
                              width: screenWidth * 0.9,
                            ),
                          ),
                        ),
                      ),
                      if (_showProceedButton)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
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
                        flex: 4,
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
                      BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
                        builder: (context, faceState) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: _showSubmitButton && faceState is FaceRecognitionCaptured && faceState.embedding.length == 512
                                ? SubmitButtonWidget(
                              student: student,
                              isRegistered: isRegistered,
                            )
                                : ButtonRowWidget(
                              controller: _controller,
                              isProcessing: _isProcessing,
                              isFaceProperNotifier: _isFaceProperNotifier,
                              onCapture: (bytes) {
                                if (bytes != null) {
                                  _pauseFaceSizeCheck();
                                  final studentId = student.fields['Student ID'];
                                  try {
                                    context.read<FaceRecognitionBloc>().add(CaptureFaceImage(
                                      bytes,
                                      isRegistered: isRegistered,
                                      studentId: studentId,
                                    ));
                                  } catch (e, stackTrace) {
                                    print('AttendancePhotoScreen: Error dispatching CaptureFaceImage: $e, stackTrace: $stackTrace');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Capture failed: $e')),
                                    );
                                    _resumeFaceSizeCheck();
                                  }
                                }
                              },
                              showSubmitButton: _showSubmitButton,
                              student: student,
                              isRegistered: isRegistered,
                            ),
                          );
                        },
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