import 'dart:typed_data';
import '../Entities/student.dart';
import '../Repositories/attendance_repository.dart';

class SubmitAttendance {
  final AttendanceRepository repository;

  SubmitAttendance(this.repository);

  Future<void> call({
    required Student student,
    required String attendanceStatus,
    Uint8List? photo,
    List<double>? faceEmbedding,
    required double latitude,
    required double longitude,
  }) async {
    await repository.submitAttendance(
      student: student,
      attendanceStatus: attendanceStatus,
      photo: photo,
      faceEmbedding: faceEmbedding,
      latitude: latitude,
      longitude: longitude,
    );
  }
}