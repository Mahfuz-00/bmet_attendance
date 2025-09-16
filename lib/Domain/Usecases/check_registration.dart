import '../Repositories/attendance_repository.dart';

class CheckRegistration {
  final AttendanceRepository repository;

  CheckRegistration(this.repository);

  Future<String> call(String studentId) async {
    return await repository.checkRegistrationStatus(studentId);
  }
}