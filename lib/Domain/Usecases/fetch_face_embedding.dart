import '../Repositories/face_recognition_repository.dart';

class FetchFaceEmbedding {
  final FaceRecognitionRepository repository;

  FetchFaceEmbedding(this.repository);

  Future<List<double>> call(String studentId) async {
    return repository.fetchFaceEmbedding(studentId);
  }
}