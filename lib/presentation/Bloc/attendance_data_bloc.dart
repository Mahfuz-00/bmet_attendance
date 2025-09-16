import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../Domain/Entities/student.dart';
import '../../Data/Models/labeled_images.dart';

abstract class AttendanceDataEvent extends Equatable {
  const AttendanceDataEvent();

  @override
  List<Object> get props => [];
}

class SetAttendanceData extends AttendanceDataEvent {
  final Map<String, String?> fields;
  final List<LabeledImage> profileImages;

  const SetAttendanceData({
    required this.fields,
    required this.profileImages,
  });

  @override
  List<Object> get props => [fields, profileImages];
}

class ClearAttendanceData extends AttendanceDataEvent {}

abstract class AttendanceDataState extends Equatable {
  const AttendanceDataState();

  @override
  List<Object?> get props => [];
}

class AttendanceDataInitial extends AttendanceDataState {}

class AttendanceDataLoaded extends AttendanceDataState {
  final Student student;

  const AttendanceDataLoaded(this.student);

  @override
  List<Object?> get props => [student];
}

class AttendanceDataBloc extends Bloc<AttendanceDataEvent, AttendanceDataState> {
  AttendanceDataBloc() : super(AttendanceDataInitial()) {
    on<SetAttendanceData>((event, emit) {
      emit(AttendanceDataLoaded(Student(
        fields: event.fields,
        profileImages: event.profileImages,
      )));
    });

    on<ClearAttendanceData>((event, emit) {
      emit(AttendanceDataInitial());
    });
  }
}