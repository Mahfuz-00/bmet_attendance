import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationApiService {
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

    print('URL: ${response.request}');
    print('Student ID: $studentId');
    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('Body: ${response.body}');
      final json = jsonDecode(response.body);
      final message = json['message'] ?? 'Not Register';
      if (message == 'Student not found') {
        return 'Not Register';
      }
      print(message);
      return message;
    } else if (response.statusCode == 400) {
      print('Body: ${response.body}');
      final json = jsonDecode(response.body);
      final message = json['message'] ?? 'Not Register';
      if (message == 'Student not found') {
        return 'Not Register';
      }
      print(message);
      return message;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('Failed to check registration: ${response.body}');
    }
  }
}