import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:touch_attendence/Core/Core/Navigation/app_router.dart';
import '../State Management/attendance_data_provider.dart';

class TextDisplayScreen extends StatelessWidget {
  const TextDisplayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final attendanceData = Provider.of<AttendanceDataProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Information')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            attendanceData.profileImages.isNotEmpty
                ? Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 4),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4.0),
                child: Image.memory(
                  attendanceData.profileImages[0].image,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                  const Text('Error loading image'),
                ),
              ),
            )
                : const SizedBox.shrink(),
            ...attendanceData.extractedFields.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
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
                  const SizedBox(width: 8),
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
            )),
            const SizedBox(height: 16),
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
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}