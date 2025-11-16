import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../Domain/Usecases/check_registration.dart';

abstract class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object> get props => [];
}

class CheckRegistrationEvent extends RegistrationEvent {
  final String studentId;

  const CheckRegistrationEvent(this.studentId);

  @override
  List<Object> get props => [studentId];
}

abstract class RegistrationState extends Equatable {
  const RegistrationState();

  @override
  List<Object> get props => [];
}

class RegistrationInitial extends RegistrationState {}

class RegistrationLoading extends RegistrationState {}

class RegistrationLoaded extends RegistrationState {
  final String status;

  const RegistrationLoaded(this.status);

  @override
  List<Object> get props => [status];
}

class RegistrationError extends RegistrationState {
  final String message;

  const RegistrationError(this.message);

  @override
  List<Object> get props => [message];
}

class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  final CheckRegistration checkRegistration;

  RegistrationBloc({required this.checkRegistration}) : super(RegistrationInitial()) {
    on<CheckRegistrationEvent>((event, emit) async {
      emit(RegistrationLoading());
      try {
        final String status = await checkRegistration(event.studentId);
        emit(RegistrationLoaded(status));
      } catch (e) {
        print('Register Bloc Error: $e');
        emit(RegistrationError(e.toString()));
      }
    });
  }
}