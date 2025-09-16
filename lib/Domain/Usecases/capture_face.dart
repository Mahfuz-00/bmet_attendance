import 'dart:typed_data';
import '../Repositories/face_recognition_repository.dart';

class CaptureFace {
  final FaceRecognitionRepository repository;

  CaptureFace(this.repository);

  Future<List<double>> call(Uint8List imageBytes) async {
    return await repository.captureFace(imageBytes);
  }
}