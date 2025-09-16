import 'package:equatable/equatable.dart';

class FaceEmbedding extends Equatable {
  final List<double> embedding;

  const FaceEmbedding({required this.embedding});

  @override
  List<Object> get props => [embedding];
}