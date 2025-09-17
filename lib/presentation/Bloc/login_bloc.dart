import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../Core/Error/failures.dart';
import '../../Domain/Entities/login_request.dart';
import '../../Domain/Entities/user.dart';
import '../../Domain/Usecases/login.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final LoginRequest request;

  const LoginSubmitted(this.request);

  @override
  List<Object> get props => [request];
}

abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final User user;

  const LoginSuccess(this.user);

  @override
  List<Object> get props => [user];
}

class LoginFailure extends LoginState {
  final String message;

  const LoginFailure(this.message);

  @override
  List<Object> get props => [message];
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final Login login;

  LoginBloc({required this.login}) : super(LoginInitial()) {
    on<LoginSubmitted>((event, emit) async {
      emit(LoginLoading());
      final result = await login(event.request);
      emit(result.fold(
            (failure) => LoginFailure(failure.message),
            (user) => LoginSuccess(user),
      ));
    });
  }
}