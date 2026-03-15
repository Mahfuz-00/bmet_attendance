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

  Future<List<double>> captureFace(Uint8List imageBytes) async {
    final result = await service.extractFaceEmbedding(imageBytes);

    // If processing is queued, just wait a bit and check again, but only once
    if (result.errorMessage == 'Processing queued, please wait') {
      print('Processing queued, waiting 1s...');
      await Future.delayed(const Duration(seconds: 1));
      final retryResult = await service.extractFaceEmbedding(imageBytes);
      if (retryResult.isSuccessful && retryResult.embedding != null) {
        return retryResult.embedding!;
      } else {
        throw Exception(retryResult.errorMessage ?? 'Failed to capture embedding after queued wait');
      }
    }

    if (result.isSuccessful && result.embedding != null) {
      return result.embedding!;
    }

    throw Exception(result.errorMessage ?? 'Failed to capture face embedding');
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
  Future<bool> verifyFace(String studentId, Uint8List imageBytes, List<double> storedEmbedding) async {
    try {
      final capturedEmbedding = await captureFace(imageBytes);
      print('Captured Embedding: $capturedEmbedding');
      if (storedEmbedding == null) {
        throw Exception('No stored embedding for $studentId');
      }
      print('Stored Embedding: $storedEmbedding');
      final result = await service.compareFaces(capturedEmbedding, storedEmbedding);
      print('Comparison result: $result');
      return result;
    } catch (e) {
      throw Exception('Failed to verify face: $e');
    }
  }
}