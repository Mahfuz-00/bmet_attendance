import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../Core/Dependecy Injection/di.dart';
import '../../Core/Navigation/app_router.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';
import '../Bloc/face_recognition_bloc.dart';
import '../Bloc/geolocation_bloc.dart';
import '../Widgets/profile_image_widget.dart';
import '../Widgets/face_preview_widget.dart';
import '../Widgets/action_button_widget.dart';
import '../../Domain/Entities/student.dart';
import '../../Domain/Usecases/submit_attendance.dart';

class AttendancePhotoScreen extends StatefulWidget {
  const AttendancePhotoScreen({Key? key}) : super(key: key);

  @override
  _AttendancePhotoScreenState createState() => _AttendancePhotoScreenState();
}

class _AttendancePhotoScreenState extends State<AttendancePhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras!.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front),
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<Uint8List?> _compressImage(Uint8List imageBytes) async {
    Uint8List compressedBytes = imageBytes;
    int quality = 95;
    const int maxSizeBytes = 100 * 1024;

    print('Original face image size: ${compressedBytes.length / 1024} KB');

    while (compressedBytes.length > maxSizeBytes && quality > 10) {
      compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 320,
        minHeight: 320,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      quality -= 10;
      print('Compressed face image size: ${compressedBytes.length / 1024} KB, quality: $quality');
    }

    if (compressedBytes.length > maxSizeBytes) {
      print('Warning: Could not compress face image below 100KB');
      return null;
    }

    return compressedBytes;
  }

  Future<Uint8List?> _captureFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not initialized')),
      );
      return null;
    }

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to compress face image below 100KB')),
        );
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/face_image.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return compressedBytes;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing face: $e')),
      );
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AttendanceDataBloc>()),
        BlocProvider(create: (_) => sl<RegistrationBloc>()),
        BlocProvider(create: (_) => sl<FaceRecognitionBloc>()),
        BlocProvider(create: (_) => sl<GeolocationBloc>()),
      ],
      child: BlocListener<FaceRecognitionBloc, FaceRecognitionState>(
        listener: (context, faceState) {
          if (faceState is FaceRecognitionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(faceState.message)),
            );
          } else if (faceState is FaceRecognitionVerified && !faceState.isMatch) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face does not match registered student')),
            );
          }
        },
        child: BlocBuilder<RegistrationBloc, RegistrationState>(
          builder: (context, regState) {
            final isRegistered = regState is RegistrationLoaded && regState.status == 'Register';
            return Scaffold(
              appBar: AppBar(title: Text(isRegistered ? 'Take Attendance' : 'Register Student')),
              body: BlocBuilder<AttendanceDataBloc, AttendanceDataState>(
                builder: (context, dataState) {
                  if (dataState is! AttendanceDataLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final student = dataState.student;
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isRegistered)
                          ProfileImageWidget(
                            profileImages: student.profileImages,
                            width: screenWidth,
                          ),
                        BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
                          builder: (context, faceState) {
                            final faceImage = faceState is FaceRecognitionCaptured ? faceState.imageBytes : null;
                            return FacePreviewWidget(
                              faceImage: faceImage,
                              cameraController: _cameraController,
                              width: screenWidth,
                              title: isRegistered ? 'Captured Face' : 'Face for Registration',
                            );
                          },
                        ),
                        BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
                          builder: (context, faceState) {
                            final isLoading = faceState is FaceRecognitionLoading;
                            final hasFace = faceState is FaceRecognitionCaptured;
                            return ActionButtonWidget(
                              label: hasFace
                                  ? 'Retake Face'
                                  : (isRegistered ? 'Take Attendance' : 'Capture Face for Registration'),
                              icon: Icons.camera_alt,
                              isLoading: isLoading,
                              onPressed: () async {
                                final faceImage = await _captureFace();
                                if (faceImage != null) {
                                  context.read<FaceRecognitionBloc>().add(CaptureFaceImage(faceImage));
                                }
                              },
                            );
                          },
                        ),
                        BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
                          builder: (context, faceState) {
                            if (faceState is! FaceRecognitionCaptured) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                BlocBuilder<GeolocationBloc, GeolocationState>(
                                  builder: (context, geoState) {
                                    return ActionButtonWidget(
                                      label: isRegistered ? 'Submit Attendance' : 'Register Student',
                                      icon: Icons.check,
                                      isLoading: geoState is GeolocationLoading,
                                      onPressed: () async {
                                        final tempDir = await getTemporaryDirectory();
                                        final tempFile = File('${tempDir.path}/face_image.jpg');
                                        try {
                                          context.read<GeolocationBloc>().add(FetchLocation());
                                          final geoState = await context.read<GeolocationBloc>().stream.firstWhere(
                                                (state) => state is GeolocationLoaded || state is GeolocationError,
                                          );
                                          if (geoState is GeolocationError) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(geoState.message)),
                                            );
                                            return;
                                          }
                                          final position = (geoState as GeolocationLoaded).position;

                                          if (isRegistered) {
                                            final studentId = student.fields['Student ID'] ?? 'Not found';
                                            if (studentId == 'Not found') {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Student ID not found')),
                                              );
                                              return;
                                            }
                                            context.read<FaceRecognitionBloc>().add(VerifyFace(studentId, faceState.imageBytes));
                                            final faceVerifyState = await context
                                                .read<FaceRecognitionBloc>()
                                                .stream
                                                .firstWhere(
                                                  (state) => state is FaceRecognitionVerified || state is FaceRecognitionError,
                                            );
                                            if (faceVerifyState is FaceRecognitionError) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(faceVerifyState.message)),
                                              );
                                              return;
                                            }
                                            if (faceVerifyState is FaceRecognitionVerified && !faceVerifyState.isMatch) {
                                              return;
                                            }
                                          }

                                          await sl<SubmitAttendance>().call(
                                            student: student,
                                            attendanceStatus: 'Yes',
                                            photo: isRegistered ? null : faceState.imageBytes,
                                            faceEmbedding: isRegistered ? null : faceState.embedding,
                                            latitude: position.latitude,
                                            longitude: position.longitude,
                                          );

                                          await tempFile.delete();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Attendance submitted successfully')),
                                          );
                                          context.read<AttendanceDataBloc>().add(ClearAttendanceData());
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            AppRoutes.qrScanner,
                                                (route) => false,
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error submitting attendance: $e')),
                                          );
                                        } finally {
                                          if (await tempFile.exists()) {
                                            await tempFile.delete();
                                          }
                                        }
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                ActionButtonWidget(
                                  label: 'Cancel and back to QR Scanner',
                                  icon: Icons.close,
                                  backgroundColor: Colors.red,
                                  onPressed: () {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      AppRoutes.qrScanner,
                                          (route) => false,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}