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

class CaptureFaceImage extends FaceRecognitionEvent {
  final Uint8List imageBytes;

  const CaptureFaceImage(this.imageBytes);

  @override
  List<Object> get props => [imageBytes];
}

class VerifyFace extends FaceRecognitionEvent {
  final String studentId;
  final Uint8List imageBytes;

  const VerifyFace(this.studentId, this.imageBytes);

  @override
  List<Object> get props => [studentId, imageBytes];
}

abstract class FaceRecognitionState extends Equatable {
  const FaceRecognitionState();

  @override
  List<Object?> get props => [];
}

class FaceRecognitionInitial extends FaceRecognitionState {}

class FaceRecognitionLoading extends FaceRecognitionState {}

class FaceRecognitionCaptured extends FaceRecognitionState {
  final Uint8List imageBytes;
  final List<double> embedding;

  const FaceRecognitionCaptured(this.imageBytes, this.embedding);

  @override
  List<Object> get props => [imageBytes, embedding];
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

  FaceRecognitionBloc({
    required this.captureFace,
    required this.fetchFaceEmbedding,
    required this.verifyFace,
  }) : super(FaceRecognitionInitial()) {
    on<CaptureFaceImage>((event, emit) async {
      emit(FaceRecognitionLoading());
      try {
        final embedding = await captureFace(event.imageBytes);
        emit(FaceRecognitionCaptured(event.imageBytes, embedding));
      } catch (e) {
        emit(FaceRecognitionError(e.toString()));
      }
    });

    on<VerifyFace>((event, emit) async {
      emit(FaceRecognitionLoading());
      try {
        print('VerifyFace instance: $verifyFace');
        final isMatch = await verifyFace(event.studentId, event.imageBytes);
        print('Face verification result: $isMatch');
        emit(FaceRecognitionVerified(isMatch));
      } catch (e) {
        print('Error in VerifyFace: $e');
        emit(FaceRecognitionError(e.toString()));
      }
    });
  }
}