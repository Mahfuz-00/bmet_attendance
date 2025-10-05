import 'dart:typed_data';
import '../../Domain/Entities/student.dart';
import '../../Domain/Repositories/attendance_repository.dart';
import '../Source/API/registration_api_service.dart';
import '../Source/API/attendance_submission_api_service.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final RegistrationApiService registrationApiService;
  final AttendanceSubmissionApiService attendanceSubmissionApiService;

  AttendanceRepositoryImpl({
    required this.registrationApiService,
    required this.attendanceSubmissionApiService,
  });

  @override
  Future<String> checkRegistrationStatus(String studentId) async {
    try {
      return await registrationApiService.checkRegistrationStatus(studentId);
    } catch (e) {
      throw Exception('Failed to check registration: $e');
    }
  }

  @override
  Future<void> submitAttendance({
    required Student student,
    required String attendanceStatus,
    Uint8List? photo,
    List<double>? faceEmbedding,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final fields = student.fields.map((key, value) => MapEntry(key, value ?? ''));
      final isRegistered = await checkRegistrationStatus(student.fields['Student ID'] ?? '');
      await attendanceSubmissionApiService.submitAttendance(
        fields: fields,
        attendanceStatus: attendanceStatus,
        photo: photo,
        faceEmbedding: faceEmbedding,
        latitude: latitude,
        longitude: longitude,
        isRegistered: isRegistered == 'Register',
      );
    } catch (e) {
      throw Exception('Failed to submit attendance: $e');
    }
  }
}