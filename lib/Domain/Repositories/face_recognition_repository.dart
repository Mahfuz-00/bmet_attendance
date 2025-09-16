import 'dart:typed_data';

abstract class FaceRecognitionRepository {
  Future<List<double>> captureFace(Uint8List imageBytes);
  Future<List<double>> fetchFaceEmbedding(String studentId);
  Future<bool> verifyFace(String studentId, Uint8List imageBytes);
}