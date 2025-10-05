import 'dart:typed_data';
import '../../Domain/Repositories/face_recognition_repository.dart';
import '../Source/API/face_recognition_service.dart';
import '../Source/API/face_embedding_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class FaceRecognitionRepositoryImpl implements FaceRecognitionRepository {
  final FaceRecognitionService service;
  final FaceEmbeddingApiService faceEmbeddingApiService;

  FaceRecognitionRepositoryImpl({
    required this.service,
    required this.faceEmbeddingApiService,
  });

  @override
  Future<List<double>> captureFace(Uint8List imageBytes) async {
    final result = await service.extractFaceEmbedding(imageBytes);
    if (result.isSuccessful && result.embedding != null) {
      print('FaceRecognitionRepositoryImpl: Embedding captured successfully');
      return result.embedding!;
    } else if (result.errorMessage == 'Processing queued, please wait') {
      print('FaceRecognitionRepositoryImpl: Processing queued');
      // Re-try until processing completes
      while (true) {
        final retryResult = await service.extractFaceEmbedding(imageBytes);
        if (retryResult.isSuccessful && retryResult.embedding != null) {
          print('FaceRecognitionRepositoryImpl: Queued embedding captured successfully');
          return retryResult.embedding!;
        } else if (retryResult.errorMessage != 'Processing queued, please wait') {
          print('FaceRecognitionRepositoryImpl: Failed to capture embedding: ${retryResult.errorMessage}');
          throw Exception(retryResult.errorMessage ?? 'Failed to capture face embedding');
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      print('FaceRecognitionRepositoryImpl: Failed to capture embedding: ${result.errorMessage}');
      throw Exception(result.errorMessage ?? 'Failed to capture face embedding');
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