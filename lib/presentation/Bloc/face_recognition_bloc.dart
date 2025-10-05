import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:typed_data';
import '../../Domain/Usecases/capture_face.dart';
import '../../Domain/Usecases/fetch_face_embedding.dart';
import '../../Domain/Usecases/verify_face.dart';

abstract class FaceRecognitionEvent extends Equatable {
  const FaceRecognitionEvent();
  @override
  List<Object> get props => [];
}

class FetchFaceEmbeddingEvent extends FaceRecognitionEvent {
  final String studentId;
  const FetchFaceEmbeddingEvent(this.studentId);
  @override
  List<Object> get props => [studentId];
}

class CaptureFaceImage extends FaceRecognitionEvent {
  final Uint8List imageBytes;
  final bool isRegistered; // Added to handle verification for registered students
  final String? studentId; // Added for verification
  const CaptureFaceImage(this.imageBytes, {required this.isRegistered, this.studentId});
  @override
  List<Object> get props => [imageBytes, isRegistered, studentId ?? ''];
}

class VerifyFace extends FaceRecognitionEvent {
  final String studentId;
  final Uint8List imageBytes;
  final List<double> storedEmbedding;
  const VerifyFace(this.studentId, this.imageBytes, this.storedEmbedding);
  @override
  List<Object> get props => [studentId, imageBytes, storedEmbedding];
}

abstract class FaceRecognitionState extends Equatable {
  const FaceRecognitionState();
  @override
  List<Object?> get props => [];
}

class FaceRecognitionInitial extends FaceRecognitionState {}

class FaceRecognitionLoading extends FaceRecognitionState {}

class FaceEmbeddingFetched extends FaceRecognitionState {
  final List<double> storedEmbedding;
  const FaceEmbeddingFetched(this.storedEmbedding);
  @override
  List<Object> get props => [storedEmbedding];
}

class FaceRecognitionCaptured extends FaceRecognitionState {
  final Uint8List imageBytes;
  final List<double> embedding;
  final List<double>? storedEmbedding;
  final bool showSubmitButton; // Added to control Submit button visibility
  const FaceRecognitionCaptured(this.imageBytes, this.embedding, {this.storedEmbedding, required this.showSubmitButton});
  @override
  List<Object?> get props => [imageBytes, embedding, storedEmbedding, showSubmitButton];
}

class FaceRecognitionVerified extends FaceRecognitionState {
  final bool isMatch;
  const FaceRecognitionVerified(this.isMatch);
  @override
  List<Object> get props => [isMatch];
}

class FaceRecognitionError extends FaceRecognitionState {
  final String message;
  const FaceRecognitionError(this.message);
  @override
  List<Object> get props => [message];
}

class FaceRecognitionBloc extends Bloc<FaceRecognitionEvent, FaceRecognitionState> {
  final CaptureFace captureFace;
  final FetchFaceEmbedding fetchFaceEmbedding;
  final VerifyFaceUseCase verifyFace;
  List<double>? _storedEmbedding;

  FaceRecognitionBloc({
    required this.captureFace,
    required this.fetchFaceEmbedding,
    required this.verifyFace,
  }) : super(FaceRecognitionInitial()) {
    on<FetchFaceEmbeddingEvent>((event, emit) async {
      emit(FaceRecognitionLoading());
      try {
        print('FaceRecognitionBloc: Fetching embedding for studentId: ${event.studentId}');
        final embedding = await fetchFaceEmbedding(event.studentId);
        if (embedding.isEmpty || embedding.length != 512) {
          print('FaceRecognitionBloc: Invalid fetched embedding, length: ${embedding.length}');
          throw Exception('Invalid face embedding: length=${embedding.length}');
        }
        _storedEmbedding = embedding;
        print('FaceRecognitionBloc: Embedding fetched: ${embedding.length} dimensions');
        emit(FaceEmbeddingFetched(embedding));
      } catch (e, stackTrace) {
        print('FaceRecognitionBloc: Error fetching embedding: $e, stackTrace: $stackTrace');
        emit(FaceRecognitionError('Failed to fetch face embedding: $e'));
      }
    });

    on<CaptureFaceImage>((event, emit) async {
      emit(FaceRecognitionLoading());
      try {
        print('FaceRecognitionBloc: Capturing face embedding for studentId: ${event.studentId}, isRegistered: ${event.isRegistered}');
        final embedding = await captureFace(event.imageBytes);
        if (embedding.isEmpty || embedding.length != 512) {
          print('FaceRecognitionBloc: Invalid embedding generated, length: ${embedding.length}');
          throw Exception('Invalid face embedding: length=${embedding.length}');
        }
        print('FaceRecognitionBloc: Face captured, embedding: ${embedding.length} dimensions');
        if (event.isRegistered && event.studentId != null) {
          if (_storedEmbedding == null) {
            print('FaceRecognitionBloc: No stored embedding for studentId: ${event.studentId}');
            throw Exception('Stored embedding not found');
          }
          print('FaceRecognitionBloc: Verifying face for registered studentId: ${event.studentId}');
          final isMatch = await verifyFace(event.studentId!, event.imageBytes);
          print('FaceRecognitionBloc: Verification result: $isMatch');
          emit(FaceRecognitionCaptured(
            event.imageBytes,
            embedding,
            storedEmbedding: _storedEmbedding,
            showSubmitButton: isMatch,
          ));
          if (!isMatch) {
            emit(FaceRecognitionError('Face does not match registered student'));
          }
        } else {
          print('FaceRecognitionBloc: Face captured for unregistered student, showing submit button');
          emit(FaceRecognitionCaptured(
            event.imageBytes,
            embedding,
            storedEmbedding: _storedEmbedding,
            showSubmitButton: true,
          ));
        }
      } catch (e, stackTrace) {
        print('FaceRecognitionBloc: Error capturing face: $e, stackTrace: $stackTrace');
        emit(FaceRecognitionError('Failed to capture face: $e'));
      }
    });

    on<VerifyFace>((event, emit) async {
      emit(FaceRecognitionLoading());
      try {
        print('FaceRecognitionBloc: Verifying face for studentId: ${event.studentId}');
        final isMatch = await verifyFace(event.studentId, event.imageBytes);
        print('FaceRecognitionBloc: Verification result: $isMatch');
        emit(FaceRecognitionVerified(isMatch));
      } catch (e, stackTrace) {
        print('FaceRecognitionBloc: Error verifying face: $e, stackTrace: $stackTrace');
        emit(FaceRecognitionError('Failed to verify face: $e'));
      }
    });
  }
}