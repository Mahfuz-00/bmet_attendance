import 'dart:typed_data';
import '../Entities/student.dart';

abstract class AttendanceRepository {
  Future<String> checkRegistrationStatus(String studentId);
  Future<void> submitAttendance({
    required Student student,
    required String attendanceStatus,
    Uint8List? photo,
    List<double>? faceEmbedding,
    required double latitude,
    required double longitude,
  });
}