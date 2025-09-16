import 'dart:typed_data';
import '../../Domain/Repositories/face_recognition_repository.dart';
import '../Source/API/face_recognition_service.dart';
import '../Source/API/face_embedding_api_service.dart';

class FaceRecognitionRepositoryImpl implements FaceRecognitionRepository {
  final FaceRecognitionService service;
  final FaceEmbeddingApiService faceEmbeddingApiService;

  FaceRecognitionRepositoryImpl({
    required this.service,
    required this.faceEmbeddingApiService,
  });

  @override
  Future<List<double>> captureFace(Uint8List imageBytes) async {
    try {
      return await service.extractFaceEmbedding(imageBytes);
    } catch (e) {
      throw Exception('Failed to capture face embedding: $e');
    }
  }

  @override
  Future<List<double>> fetchFaceEmbedding(String studentId) async {
    try {
      return await faceEmbeddingApiService.getFaceEmbedding(studentId);
    } catch (e) {
      throw Exception('Failed to fetch face embedding: $e');
    }
  }

  @override
  Future<bool> verifyFace(String studentId, Uint8List imageBytes) async {
    try {
      final capturedEmbedding = await captureFace(imageBytes);
      final storedEmbedding = await fetchFaceEmbedding(studentId);
      return await service.compareFaces(capturedEmbedding, storedEmbedding);
    } catch (e) {
      throw Exception('Failed to verify face: $e');
    }
  }
}