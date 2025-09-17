import 'package:dartz/dartz.dart';
import '../../Core/Error/failures.dart';
import '../Entities/user.dart';
import '../Entities/login_request.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(LoginRequest request);
}