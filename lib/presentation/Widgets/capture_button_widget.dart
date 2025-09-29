import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../Presentation/Bloc/face_recognition_bloc.dart';
import '../Widgets/action_button_widget.dart';

class CaptureButtonWidget extends StatefulWidget {
  final bool isRegistered;

  const CaptureButtonWidget({Key? key, required this.isRegistered}) : super(key: key);

  @override
  _CaptureButtonWidgetState createState() => _CaptureButtonWidgetState();
}

class _CaptureButtonWidgetState extends State<CaptureButtonWidget> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front),
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
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
    return BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
      builder: (context, faceState) {
        final isLoading = faceState is FaceRecognitionLoading;
        final hasFace = faceState is FaceRecognitionCaptured;
        return ActionButtonWidget(
          label: hasFace
              ? 'Retake Face'
              : (widget.isRegistered ? 'Take Attendance' : 'Capture Face for Registration'),
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
    );
  }
}