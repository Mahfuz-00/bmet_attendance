import 'package:equatable/equatable.dart';

class LoginResponse extends Equatable {
  final String? token;
  final String? message;

  const LoginResponse({this.token, this.message});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String?,
      message: json['message'] as String?,
    );
  }

  @override
  List<Object?> get props => [token, message];
}