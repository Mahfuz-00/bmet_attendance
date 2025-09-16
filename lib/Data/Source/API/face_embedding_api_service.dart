import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FaceEmbeddingApiService {
  static const String _baseUrl = 'http://qratn.alhadiexpress.com.bd/api';

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
}