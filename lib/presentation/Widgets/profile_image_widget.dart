import 'package:flutter/material.dart';
import '../../Common/Config/Theme/app_colors.dart';
import '../../Data/Models/labeled_images.dart';

class ProfileImageWidget extends StatelessWidget {
  final List<LabeledImage> profileImages;
  final double width;

  const ProfileImageWidget({
    Key? key,
    required this.profileImages,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          const Text(
            'Student ID Image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          profileImages.isNotEmpty &&
              profileImages[0].image != null &&
              profileImages[0].image!.isNotEmpty
              ? Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4.0),
            child: Image.memory(
              profileImages[0].image,
              height: 200,
              width: width * 0.6,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Error loading image',
                style: TextStyle(color: Colors.red),
              ),
            ),
          )
              : Container(
            width: width * 0.7,
            height: width * 0.7,
            color: Colors.blueGrey,
            child: const Center(
              child: Text(
                'No profile image available',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}