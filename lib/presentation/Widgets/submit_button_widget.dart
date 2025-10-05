import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../Core/Dependecy Injection/di.dart';
import '../../Core/Navigation/app_router.dart';
import '../../Domain/Entities/student.dart';
import '../../Domain/Usecases/submit_attendance.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/face_recognition_bloc.dart';
import '../Bloc/geolocation_bloc.dart';
import '../Widgets/action_button_widget.dart';

class SubmitButtonWidget extends StatelessWidget {
  final Student student;
  final bool isRegistered;

  const SubmitButtonWidget({
    Key? key,
    required this.student,
    required this.isRegistered,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FaceRecognitionBloc, FaceRecognitionState>(
      builder: (context, faceState) {
        if (faceState is! FaceRecognitionCaptured) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<GeolocationBloc, GeolocationState>(
          builder: (context, geoState) {
            return ActionButtonWidget(
              label: isRegistered ? 'Submit Attendance' : 'Register Student',
              icon: Icons.check,
              isLoading: geoState is GeolocationLoading,
              onPressed: () async {
                final tempDir = await getTemporaryDirectory();
                final tempFile = File('${tempDir.path}/face_image.jpg');
                try {
                  context.read<GeolocationBloc>().add(FetchLocation());
                  final geoState = await context.read<GeolocationBloc>().stream.firstWhere(
                        (state) => state is GeolocationLoaded || state is GeolocationError,
                  );
                  if (geoState is GeolocationError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(geoState.message)),
                    );
                    return;
                  }
                  final position = (geoState as GeolocationLoaded).position;

                  if (isRegistered) {
                    final studentId = student.fields['Student ID'] ?? 'Not found';
                    if (studentId == 'Not found') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Student ID not found')),
                      );
                      return;
                    }
                    if (faceState.storedEmbedding != null) {
                      print('SubmitButtonWidget: Verifying face for studentId: $studentId');
                      context.read<FaceRecognitionBloc>().add(VerifyFace(studentId, faceState.imageBytes, faceState.storedEmbedding!));
                      final faceVerifyState = await context
                          .read<FaceRecognitionBloc>()
                          .stream
                          .firstWhere(
                            (state) => state is FaceRecognitionVerified || state is FaceRecognitionError,
                      );
                      if (faceVerifyState is FaceRecognitionError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(faceVerifyState.message)),
                        );
                        return;
                      }
                      if (faceVerifyState is FaceRecognitionVerified && !faceVerifyState.isMatch) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Face does not match registered student')),
                        );
                        return;
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stored face embedding not available')),
                      );
                      return;
                    }
                  }

                  Map<String, String?> filteredFields = isRegistered
                      ? {'Student ID': student.fields['Student ID'] ?? ''}
                      : student.fields;

                  print('SubmitButtonWidget: Submitting attendance for studentId: ${student.fields['Student ID']}');
                  await sl<SubmitAttendance>().call(
                    student: Student(fields: filteredFields, profileImages: student.profileImages),
                    attendanceStatus: 'Yes',
                    photo: isRegistered ? null : faceState.imageBytes,
                    faceEmbedding: isRegistered ? null : faceState.embedding,
                    latitude: position.latitude,
                    longitude: position.longitude,
                  );

                  await tempFile.delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance submitted successfully')),
                  );
                  context.read<AttendanceDataBloc>().add(ClearAttendanceData());
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.qrScanner,
                        (route) => false,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error submitting attendance: $e')),
                  );
                } finally {
                  if (await tempFile.exists()) {
                    await tempFile.delete();
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}