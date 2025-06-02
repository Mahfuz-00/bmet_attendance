import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:touch_attendence/presentation/Screens/qrscanner.dart';

class TextDisplayScreen extends StatelessWidget {
  final String text;
  final List<Uint8List> images;
  final List<String> imageTexts;
  final List<String> profileDetections;
  final List<LabeledImage> profileImages;
  final Map<String, String> extractedFields;

  const TextDisplayScreen({
    Key? key,
    required this.text,
    this.images = const [],
    this.imageTexts = const [],
    this.profileDetections = const [],
    this.profileImages = const [],
    this.extractedFields = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extracted PDF Content')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extracted Fields:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...extractedFields.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 16),
              ),
            )),
            const SizedBox(height: 16),
            const Text(
              'Full Extracted Text:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              text.isEmpty ? 'No text found' : text,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Images:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            profileImages.isEmpty
                ? const Text('No profile images found', style: TextStyle(fontSize: 16))
                : Column(
              children: profileImages.map((labeledImage) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labeledImage.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4.0),
                      child: Image.memory(
                        labeledImage.image,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text('Error loading image'),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Extracted Images:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            images.isEmpty
                ? const Text('No images found', style: TextStyle(fontSize: 16))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isProfile = index < profileDetections.length && profileDetections[index] == 'Yes';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: isProfile
                          ? BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 4),
                        borderRadius: BorderRadius.circular(8),
                      )
                          : null,
                      child: Padding(
                        padding: isProfile ? const EdgeInsets.all(4.0) : EdgeInsets.zero,
                        child: Image.memory(
                          images[index],
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Text('Error loading image'),
                        ),
                      ),
                    ),
                    if (isProfile)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Profile Image',
                          style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Text(
                      'Image ${index + 1} Text:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      index < imageTexts.length && imageTexts[index].isNotEmpty
                          ? imageTexts[index]
                          : 'No embedded text found',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profile Image Detected:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      index < profileDetections.length ? profileDetections[index] : 'Not analyzed',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}