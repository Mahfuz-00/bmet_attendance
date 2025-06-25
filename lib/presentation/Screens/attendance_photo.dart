import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../Core/Core/Navigation/app_router.dart';
import '../State Management/attendance_data_provider.dart';
import 'dart:convert';

class AttendancePhotoScreen extends StatefulWidget {
  const AttendancePhotoScreen({Key? key}) : super(key: key);

  @override
  _AttendancePhotoScreenState createState() => _AttendancePhotoScreenState();
}

class _AttendancePhotoScreenState extends State<AttendancePhotoScreen> {
  Uint8List? _attendancePhoto;
  bool _isSubmitting = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _attendancePhoto = bytes;
      });
    }
  }

  Future<void> _submitAttendance() async {
    if (_attendancePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take an attendance photo')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final attendanceData = Provider.of<AttendanceDataProvider>(context, listen: false);
      print('AttendancePhoto: Provider data - Fields: ${attendanceData.extractedFields.length}, Images: ${attendanceData.profileImages.length}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://smartatn.touchandsolve.com/api/user/attendance'),
      );

      request.fields['name'] = attendanceData.extractedFields['Name'] ?? 'Not found';
      request.fields['father_name'] = attendanceData.extractedFields["Father's Name"] ?? 'Not found';
      request.fields['mother_name'] = attendanceData.extractedFields["Mother's Name"] ?? 'Not found';
      request.fields['passport_no'] = attendanceData.extractedFields['Passport No'] ?? 'Not found';
      request.fields['destination_country'] = attendanceData.extractedFields['Destination Country'] ?? 'Not found';
      request.fields['batch_no'] = attendanceData.extractedFields['Batch No'] ?? 'Not found';
      request.fields['room_no'] = attendanceData.extractedFields['Room No'] ?? 'Not found';
      request.fields['student_id'] = attendanceData.extractedFields['Student ID'] ?? 'Not found';
      request.fields['roll_no'] = attendanceData.extractedFields['Roll No'] ?? 'Not found';
      request.fields['institute_name'] = attendanceData.extractedFields['Venue / Institute'] ?? 'Not found';
      request.fields['course_start_date'] = attendanceData.extractedFields['Course Date']?.split(' to ')[0] ?? 'Not found';
      request.fields['course_end_date'] = attendanceData.extractedFields['Course Date']?.split(' to ')[1] ?? 'Not found';
      request.fields['couse_start_time'] = attendanceData.extractedFields['Course Time']?.split(' to ')[0] ?? 'Not found';
      request.fields['course_end_time'] = attendanceData.extractedFields['Course Time']?.split(' to ')[1] ?? 'Not found';
      request.fields['institute_id'] = 'Not provided';

      // Only add profile image if available
      if (attendanceData.profileImages.isNotEmpty) {
        print('AttendancePhoto: Adding profile image');
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          attendanceData.profileImages[0].image,
          filename: 'profile_photo.png',
        ));
      } else {
        print('AttendancePhoto: No profile image available');
      }

      request.files.add(http.MultipartFile.fromBytes(
        'attendance_photo',
        _attendancePhoto!,
        filename: 'attendance_photo.png',
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('AttendancePhoto: Response status: ${response.statusCode}, body: $responseBody');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance submitted successfully')),
        );
        Provider.of<AttendanceDataProvider>(context, listen: false).clearData();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.qrScanner,
              (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit attendance: $responseBody')),
        );
      }
    } catch (e) {
      print('AttendancePhoto: Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_attendancePhoto != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.memory(
                  _attendancePhoto!,
                  width: screenWidth * 0.7,
                  fit: BoxFit.contain,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, color: Colors.black),
                label: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: Size(screenWidth * 0.8, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            if (_attendancePhoto != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAttendance,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Submit Student Attendance',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: Size(screenWidth * 0.8, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}