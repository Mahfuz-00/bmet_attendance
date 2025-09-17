import 'package:dartz/dartz.dart';

import '../../Core/Error/failures.dart';
import '../Entities/user.dart';
import '../Entities/login_request.dart';
import '../Repositories/auth_repository.dart';

class Login {
  final AuthRepository repository;

  Login(this.repository);

  Future<Either<Failure, User>> call(LoginRequest request) async {
    return await repository.login(request);
  }
}