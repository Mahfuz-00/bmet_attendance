import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../Common/Config/Theme/app_colors.dart';

class FacePreviewWidget extends StatelessWidget {
  final Uint8List? faceImage;
  final CameraController? cameraController;
  final double width;
  final String title;

  const FacePreviewWidget({
    Key? key,
    this.faceImage,
    this.cameraController,
    required this.width,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          faceImage != null
              ? Image.memory(
            faceImage!,
            width: width * 0.7,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: width * 0.7,
              height: width * 0.7,
              color: Colors.blueGrey,
              child: const Center(
                child: Text(
                  'Failed to load face image',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          )
              : cameraController != null && cameraController!.value.isInitialized
              ? SizedBox(
            width: width * 0.7,
            height: width * 0.7,
            child: CameraPreview(cameraController!),
          )
              : Container(
            width: width * 0.7,
            height: width * 0.7,
            color: Colors.blueGrey,
            child: const Center(
              child: Text(
                'Camera not available',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}