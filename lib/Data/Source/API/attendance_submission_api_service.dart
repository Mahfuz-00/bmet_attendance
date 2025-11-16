import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSubmissionApiService {
  static const String _baseUrl = 'http://qratn.alhadiexpress.com.bd/api';

  Future<void> submitAttendance({
    required Map<String, String> fields,
    required String attendanceStatus,
    Uint8List? photo,
    List<double>? faceEmbedding,
    required double latitude,
    required double longitude,
    required bool isRegistered,
  }) async {
    print('AttendanceSubmissionApiService: Starting submitAttendance');
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) {
      print('AttendanceSubmissionApiService: No auth token found');
      throw Exception('Authentication token not found');
    }

    print('AttendanceSubmissionApiService: Preparing request');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/attendance'),
    );

    request.headers['Authorization'] = 'Bearer $authToken';
    request.headers['Content-Type'] = 'multipart/form-data';

    print('AttendanceSubmissionApiService: Mapping fields');
    final mappedFields = {
      'name': fields['Name'] ?? '',
      'father_name': fields['Father\'s Name'] ?? '',
      'mother_name': fields['Mother\'s Name'] ?? '',
      'nid': fields['NID / Birth Reg. No.'] ?? '',
      'passport_no': fields['Passport No'] ?? '',
      'destination_country': fields['Destination Country'] ?? '',
      'room_no': fields['Room No'] ?? '',
      'student_id': fields['Student ID'] ?? '',
      'roll_no': fields['Roll No'] ?? '',
      'batch_no': fields['Batch No']?.split(' (')[0] ?? '', // Extract "NoakhaliTTCBMETPDO0073"
      'institute_name': fields['Venue / Institute'] ?? '',
      'course_start_date': fields['Course Date'] ?? '',
      'couse_start_time': fields['Course Time'] ?? '',
    };

    print('AttendanceSubmissionApiService: Preparing request fields for isRegistered=$isRegistered');
    final requestFields = <String, String>{};
    if (isRegistered) {
      print('AttendanceSubmissionApiService: Building attendance payload');
      requestFields.addAll({
        'student_id': mappedFields['student_id']!,
        'attendance_status': attendanceStatus,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'request_type': 'attendance',
      });
    } else {
      print('AttendanceSubmissionApiService: Building registration payload');
      requestFields.addAll(mappedFields);
      requestFields.addAll({
        'attendance_status': attendanceStatus,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'request_type': 'registration',
      });

      print('AttendanceSubmissionApiService: Adding photo');
      if (photo != null) {
        print('AttendanceSubmissionApiService: Photo: $photo');
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          photo,
          filename: 'attendance_photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      print('AttendanceSubmissionApiService: Adding face embedding');
      if (faceEmbedding != null) {
        requestFields['face_embedding'] = jsonEncode(faceEmbedding);
      }
    }

    print('AttendanceSubmissionApiService: Request payload: ${jsonEncode(requestFields)}');
    print('AttendanceSubmissionApiService: Photo provided: ${photo != null}');
    print('AttendanceSubmissionApiService: Face embedding provided: ${faceEmbedding != null}');

    request.fields.addAll(requestFields);

    print('AttendanceSubmissionApiService: Sending request');
    try {
      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      print('AttendanceSubmissionApiService: Status Code: ${response.statusCode}');
      print('AttendanceSubmissionApiService: URL: ${response.request}');
      print('AttendanceSubmissionApiService: Response Body: $responseBody');

      if (response.statusCode == 200) {
        print('AttendanceSubmissionApiService: Attendance submitted successfully: $responseBody');
      } else if (response.statusCode == 401) {
        print('AttendanceSubmissionApiService: Unauthorized error');
        throw Exception('Unauthorized: Please log in again');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(responseBody);
        final errorMessage = errorData['message'] ?? 'Validation error';
        print('AttendanceSubmissionApiService: Validation error: $errorMessage');
        throw Exception('Validation error: $errorMessage');
      } else {
        print('AttendanceSubmissionApiService: Failed with status: ${response.statusCode}');
        throw Exception('Failed to submit attendance: $responseBody');
      }
    } catch (e) {
      print('AttendanceSubmissionApiService: Error submitting attendance: $e');
      rethrow;
    }
  }
}