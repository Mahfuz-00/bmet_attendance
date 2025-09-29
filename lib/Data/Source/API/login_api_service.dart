import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../Common/Config/Constants/app_urls.dart';
import '../../Models/login_request.dart';
import '../../Models/login_response.dart';

class LoginApiService {
  Future<LoginResponse> login(LoginRequest request) async {
    print('Request: ${request.toJson()}');

    final response = await http.post(
      Uri.parse('${AppUrls.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    print('Status Code : ${response.statusCode}');
    print('Body : ${response.body}');
    print('URL : ${response.request}');

    return LoginResponse.fromJson(jsonDecode(response.body));
  }
}