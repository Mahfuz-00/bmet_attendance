import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Core/Error/failures.dart';
import '../../Domain/Entities/user.dart';
import '../../Domain/Entities/login_request.dart';
import '../../Domain/Repositories/auth_repository.dart';
import '../Source/API/login_api_service.dart';
import '../Models/login_request.dart' as model;

class AuthRepositoryImpl implements AuthRepository {
  final LoginApiService apiService;
  final SharedPreferences prefs;

  AuthRepositoryImpl({required this.apiService, required this.prefs});

  @override
  Future<Either<Failure, User>> login(LoginRequest request) async {
    try {
      final response = await apiService.login(model.LoginRequest(
        email: request.email,
        password: request.password,
      ));
      if (response.token != null) {
        await prefs.setString('auth_token', response.token!);
        await prefs.setBool('is_logged_in', true);
        return Right(User(token: response.token!));
      } else {
        return Left(ServerFailure(response.message ?? 'Login failed'));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}