import 'package:equatable/equatable.dart';

class LoginRequest extends Equatable {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}