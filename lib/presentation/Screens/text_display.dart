import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:touch_attendence/Core/Core/Navigation/app_router.dart';
import '../../Common/Common/Config/Theme/app_colors.dart';
import '../State Management/attendance_data_provider.dart';

class TextDisplayScreen extends StatelessWidget {
  const TextDisplayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final attendanceData = Provider.of<AttendanceDataProvider>(context);

    // Filter fields to show only valid data (not null, not empty, not 'Not found')
    final filteredEntries = attendanceData.extractedFields.entries
        .where((entry) =>
    entry.value != null &&
        entry.value!.isNotEmpty &&
        entry.value != 'Not found')
        .toList();

    // Remove duplicates by key, keep first occurrence only
    final uniqueEntriesMap = <String, String>{};
    for (var entry in filteredEntries) {
      if (!uniqueEntriesMap.containsKey(entry.key)) {
        uniqueEntriesMap[entry.key] = entry.value!;
      }
    }

    // Custom sort order groups by substring matching (case-insensitive)
    final nameTypeSubstrings = ['name', "father's", "mother's"];
    final idTypeSubstrings = ['no', 'id', 'code', 'destination country'];
    final venueCourseType = ['venue', 'course'];

    bool containsAny(String key, List<String> substrings) {
      final lowerKey = key.toLowerCase();
      return substrings.any((sub) => lowerKey.contains(sub));
    }

    // Sort keys by group order
    final sortedKeys = [
      ...uniqueEntriesMap.keys.where((k) => containsAny(k, nameTypeSubstrings)),
      ...uniqueEntriesMap.keys.where((k) =>
      !containsAny(k, nameTypeSubstrings) &&
          containsAny(k, idTypeSubstrings)),
      ...uniqueEntriesMap.keys.where((k) =>
      !containsAny(k, nameTypeSubstrings) &&
          !containsAny(k, idTypeSubstrings) &&
          containsAny(k, venueCourseType)),
      ...uniqueEntriesMap.keys.where((k) =>
      !containsAny(k, nameTypeSubstrings) &&
          !containsAny(k, idTypeSubstrings) &&
          !containsAny(k, venueCourseType)),
    ];

    final validFields = sortedKeys
        .map((key) => MapEntry(key, uniqueEntriesMap[key]!))
        .toList();

    // Check if any data or profile images
    final hasData = validFields.isNotEmpty || attendanceData.profileImages.isNotEmpty;

    // If no valid data, navigate to QRScannerScreen fresh (avoid pop)
    if (!hasData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found. Please scan a valid QR code.')),
        );
        // Navigate to QRScannerScreen, removing this screen from stack
        Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Information'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Image
              attendanceData.profileImages.isNotEmpty
                  ? Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4.0),
                  child: Image.memory(
                    attendanceData.profileImages[0].image,
                    height: 200,
                    width: screenWidth * 0.6,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'Error loading image',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              )
                  : const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'No profile image available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              // Valid Fields
              if (validFields.isNotEmpty)
                ...validFields.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${entry.key}:',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.left,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ))
              else
                const Text(
                  'No fields extracted',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              const SizedBox(height: 24),
              // Attendance Photo Button
              SizedBox(
                width: screenWidth * 0.8,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.attendancePhoto);
                  },
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Take Attendance Photo',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}