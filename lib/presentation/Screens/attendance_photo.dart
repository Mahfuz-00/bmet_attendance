import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import '../../Common/Common/Config/Theme/app_colors.dart';
import '../../Core/Core/Navigation/app_router.dart';
import '../State Management/attendance_data_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class AttendancePhotoScreen extends StatefulWidget {
  const AttendancePhotoScreen({Key? key}) : super(key: key);

  @override
  _AttendancePhotoScreenState createState() => _AttendancePhotoScreenState();
}

class _AttendancePhotoScreenState extends State<AttendancePhotoScreen> {
  Uint8List? _attendancePhoto;
  bool _isSubmitting = false;

  Future<Uint8List?> _compressImage(Uint8List imageBytes, String imageType) async {
    // Compressing the image to reduce size to under 5MB
    Uint8List compressedBytes = imageBytes;
    int quality = 85; // Initial quality (0-100)
    const int maxSizeBytes = 5 * 1024 * 1024; // 5MB in bytes

    print('Original $imageType size: ${compressedBytes.length / 1024 / 1024} MB');

    while (compressedBytes.length > maxSizeBytes && quality > 10) {
      compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1024, // Reduce resolution
        minHeight: 1024,
        quality: quality, // Adjust quality
        format: imageType == 'profile' ? CompressFormat.png : CompressFormat.jpeg, // PNG for profile, JPEG for attendance
      );
      quality -= 10; // Reduce quality incrementally if still too large
      print('Compressed $imageType size: ${compressedBytes.length / 1024 / 1024} MB, quality: $quality');
    }

    if (compressedBytes.length > maxSizeBytes) {
      print('Warning: Could not compress $imageType below 5MB, current size: ${compressedBytes.length / 1024 / 1024} MB');
      return null; // Return null if compression fails to meet size requirement
    }

    return compressedBytes;
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      // Compress the attendance photo
      final compressedBytes = await _compressImage(bytes, 'attendance');
      if (compressedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to compress attendance photo below 5MB')),
        );
        return;
      }

      setState(() {
        _attendancePhoto = compressedBytes;
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
        Uri.parse('http://qratn.alhadiexpress.com.bd/api/user/attendance'),
      );

      // Add Authorization header
      request.headers['Authorization'] = 'Bearer $authToken';
      print('AttendancePhoto: Authorization header set: Bearer $authToken');
      request.headers['Content-Type'] = 'multipart/form-data';

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
      request.fields['course_start_time'] = courseStartTime; // Fixed typo: 'couse' to 'course'
      print('Fields: ${request.fields}');
      request.fields['course_end_time'] = courseEndTime;
      print('Fields: ${request.fields}');

      // Validate and compress profile image
      if (attendanceData.profileImages.isNotEmpty) {
        final profileImage = attendanceData.profileImages[0].image;
        if (profileImage != null && profileImage.isNotEmpty) {
          // Check for PNG header (137, 80, 78, 71)
          if (profileImage.length >= 4 && profileImage[0] == 137 && profileImage[1] == 80 && profileImage[2] == 78 && profileImage[3] == 71) {
            // Compress profile image
            final compressedProfileImage = await _compressImage(profileImage, 'profile');
            if (compressedProfileImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to compress profile image below 5MB')),
              );
              setState(() {
                _isSubmitting = false;
              });
              return;
            }
            print('AttendancePhoto: Adding profile image, bytes: ${compressedProfileImage.length}, first bytes: ${compressedProfileImage.sublist(0, 4)}');
            request.files.add(http.MultipartFile.fromBytes(
              'rg_photo',
              compressedProfileImage,
              filename: 'profile_image.png',
              contentType: MediaType('image', 'png'),
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

      // Validate and add compressed attendance photo
      if (_attendancePhoto != null) {
        print('AttendancePhoto: Adding attendance photo, bytes: ${_attendancePhoto!.length}, first bytes: ${_attendancePhoto!.sublist(0, 4)}');
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          _attendancePhoto!,
          filename: 'attendance_photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        print('AttendancePhoto: No image Taken');
      }

      // Log request details for debugging
      print('Request headers: ${request.headers}');
      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.length} files attached');

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();
      print('AttendancePhoto: Response status: ${response.statusCode}, body: $responseBody');

      if (response.statusCode == 200) {
        print('Successfully Submitted: ${responseBody}');
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

  bool _canSubmit() {
    // Check if both profile image and attendance photo are available and rendered
    final attendanceData = Provider.of<AttendanceDataProvider>(context, listen: false);
    return attendanceData.profileImages.isNotEmpty &&
        attendanceData.profileImages[0].image != null &&
        attendanceData.profileImages[0].image!.isNotEmpty &&
        _attendancePhoto != null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final attendanceData = Provider.of<AttendanceDataProvider>(context, listen: false);

    // Define a unified button style to match the provided button
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      disabledBackgroundColor: Colors.grey,
      minimumSize: Size(screenWidth * 0.8, 0), // Match provided button: width only, no fixed height
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontSize: 16),
    );

    // Define style for Cancel button with red background
    final cancelButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red, // Red background for Cancel button
      disabledBackgroundColor: Colors.grey,
      minimumSize: Size(screenWidth * 0.8, 0), // Same size as other buttons
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontSize: 16),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              // Attendance Image or Take Photo Button
              if (_attendancePhoto != null) ...[
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
                // Retake Photo Button
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, color: Colors.black, size: 24),
                  label: const Text(
                    'Retake Photo',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: buttonStyle,
                ),
                const SizedBox(height: 16),
              ] else
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, color: Colors.black, size: 24),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: buttonStyle,
                ),
              // Submit Button
              if (_attendancePhoto != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _canSubmit() && !_isSubmitting ? _submitAttendance : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.check, color: Colors.black, size: 24),
                  label: const Text(
                    'Submit Student Attendance',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  style: buttonStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.qrScanner,
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.close, color: Colors.black, size: 24),
                  label: const Text(
                    'Cancel and back to QR Scanner',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: cancelButtonStyle,
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