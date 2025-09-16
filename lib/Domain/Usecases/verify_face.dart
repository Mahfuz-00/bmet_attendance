import 'dart:typed_data';
import '../Repositories/face_recognition_repository.dart';

class VerifyFaceUseCase {
  final FaceRecognitionRepository repository;

  VerifyFaceUseCase(this.repository);

  Future<bool> call(String studentId, Uint8List imageBytes) async {
    return await repository.verifyFace(studentId, imageBytes);
  }
}