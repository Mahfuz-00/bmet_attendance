import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../../Common/Common/Config/Theme/app_colors.dart';
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
    print('Submitting');
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
      print('Extracted Datas: ${attendanceData.extractedFields}');
      print('Profile Image: ${attendanceData.profileImages.isNotEmpty ? attendanceData.profileImages[0].image : 'No image'}');
      print('Attendance Photo bytes: ${_attendancePhoto!.length}, first bytes: ${_attendancePhoto!.sublist(0, 4)}');


      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token not found. Please log in again.');
      }


      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://smartatn.touchandsolve.com/api/user/attendance'),
      );

      // Add Authorization header
      request.headers['Authorization'] = 'Bearer $authToken';
      print('AttendancePhoto: Authorization header set: Bearer $authToken');

      request.fields['name'] = attendanceData.extractedFields['Name'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['father_name'] = attendanceData.extractedFields["Father's Name"] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['mother_name'] = attendanceData.extractedFields["Mother's Name"] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['passport_no'] = attendanceData.extractedFields['Passport No'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['destination_country'] = attendanceData.extractedFields['Destination Country'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['batch_no'] = attendanceData.extractedFields['Batch No'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['room_no'] = attendanceData.extractedFields['Room No'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['student_id'] = attendanceData.extractedFields['Student ID'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['roll_no'] = attendanceData.extractedFields['Roll No'] ?? 'Not found';
      print('Fields: ${request.fields}');
      request.fields['institute_name'] = attendanceData.extractedFields['Venue / Institute'] ?? 'Not found';
      print('Fields: ${request.fields}');

      // Parse Course Date
      final courseDate = attendanceData.extractedFields['Course Date'] ?? 'Not found';
      String courseStartDate = 'Not found';
      String courseEndDate = 'Not found';
      if (courseDate != 'Not found') {
        final dateParts = courseDate.split(RegExp(r'\s+[tT][oO]\s+'));
        if (dateParts.length == 2) {
          courseStartDate = dateParts[0].trim();
          courseEndDate = dateParts[1].trim();
        } else {
          print('AttendancePhoto: Invalid Course Date format: $courseDate');
          courseStartDate = courseDate;
        }
      }
      request.fields['course_start_date'] = courseStartDate;
      print('Fields: ${request.fields}');
      request.fields['course_end_date'] = courseEndDate;
      print('Fields: ${request.fields}');

      // Parse Course Time
      final courseTime = attendanceData.extractedFields['Course Time'] ?? 'Not found';
      String courseStartTime = 'Not found';
      String courseEndTime = 'Not found';
      if (courseTime != 'Not found') {
        final timeParts = courseTime.split(RegExp(r'\s+[tT][oO]\s+'));
        if (timeParts.length == 2) {
          courseStartTime = timeParts[0].trim();
          courseEndTime = timeParts[1].trim();
        } else {
          print('AttendancePhoto: Invalid Course Time format: $courseTime');
          courseStartTime = courseTime;
        }
      }
      request.fields['couse_start_time'] = courseStartTime;
      print('Fields: ${request.fields}');
      request.fields['course_end_time'] = courseEndTime;
      print('Fields: ${request.fields}');

      request.fields['institute_id'] = 'Not provided';
      print('Fields: ${request.fields}');

      // Validate profile image
      if (attendanceData.profileImages.isNotEmpty) {
        final profileImage = attendanceData.profileImages[0].image;
        if (profileImage != null && profileImage.isNotEmpty) {
          // Check for PNG header (137, 80, 78, 71)
          if (profileImage.length >= 4 && profileImage[0] == 137 && profileImage[1] == 80 && profileImage[2] == 78 && profileImage[3] == 71) {
            print('AttendancePhoto: Adding profile image, bytes: ${profileImage.length}, first bytes: ${profileImage.sublist(0, 4)}');
            request.files.add(http.MultipartFile.fromBytes(
              'photo',
              profileImage,
              filename: 'profile_photo.png',
            ));
          } else {
            print('AttendancePhoto: Profile image has invalid PNG header, bytes: ${profileImage.length}, first bytes: ${profileImage.sublist(0, profileImage.length < 4 ? profileImage.length : 4)}');
          }
        } else {
          print('AttendancePhoto: Profile image is null or empty');
        }
      } else {
        print('AttendancePhoto: No profile image available');
      }

      // Validate attendance photo
      print('AttendancePhoto: Adding attendance photo, bytes: ${_attendancePhoto!.length}, first bytes: ${_attendancePhoto!.sublist(0, 4)}');
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
      } else if (response.statusCode == 401) {
        // Handle unauthorized error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unauthorized: Please log in again')),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.setBool('is_logged_in', false);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
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
    final attendanceData = Provider.of<AttendanceDataProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_attendancePhoto != null) ...[
                // Profile Image
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      attendanceData.profileImages.isNotEmpty &&
                          attendanceData.profileImages[0].image != null &&
                          attendanceData.profileImages[0].image!.isNotEmpty
                          ? Image.memory(
                        attendanceData.profileImages[0].image!,
                        width: screenWidth * 0.7,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: screenWidth * 0.7,
                          height: screenWidth * 0.7,
                          color: Colors.blueGrey,
                          child: const Center(
                            child: Text(
                              'Failed to load profile image',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      )
                          : Container(
                        width: screenWidth * 0.7,
                        height: screenWidth * 0.7,
                        color: Colors.blueGrey,
                        child: const Center(
                          child: Text(
                            'No profile image available',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Attendance Image
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Attendance Image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Image.memory(
                        _attendancePhoto!,
                        width: screenWidth * 0.7,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: screenWidth * 0.7,
                          height: screenWidth * 0.7,
                          color: Colors.blueGrey,
                          child: const Center(
                            child: Text(
                              'Failed to load attendance image',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, color: Colors.black),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
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
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : const Text(
                    'Submit Student Attendance',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: Size(screenWidth * 0.8, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}