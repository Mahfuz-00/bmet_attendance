import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceApiService {
  static const String _baseUrl = 'http://qratn.alhadiexpress.com.bd/api';

  Future<String> checkRegistrationStatus(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/check-registration?student_id=$studentId'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    print('Status Code : ${response.statusCode}');
    print('Body : ${response.body}');
    print('URL : ${response.request}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['message'] ?? 'Not Register';
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to check registration: ${response.body}');
    }
  }

  Future<List<double>> getFaceEmbedding(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/face-embedding?student_id=$studentId'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return List<double>.from(json['embedding']);
    } else {
      throw Exception('Failed to fetch face embedding: ${response.body}');
    }
  }

  Future<void> submitAttendance({
    required Map<String, String> fields,
    required String attendanceStatus,
    Uint8List? photo,
    List<double>? faceEmbedding,
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) {
      throw Exception('Authentication token not found');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/user/attendance'),
    );

    request.headers['Authorization'] = 'Bearer $authToken';
    request.headers['Content-Type'] = 'multipart/form-data';

    request.fields.addAll(fields);
    request.fields['attendance_status'] = attendanceStatus;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    if (photo != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photo,
        filename: 'attendance_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (faceEmbedding != null) {
      request.fields['face_embedding'] = jsonEncode(faceEmbedding);
    }

    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print('Attendance submitted successfully: $responseBody');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to submit attendance: $responseBody');
    }
  }
}