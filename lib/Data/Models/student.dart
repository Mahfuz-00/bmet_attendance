import 'package:equatable/equatable.dart';
import 'labeled_images.dart';

class Student extends Equatable {
  final Map<String, String?> fields;
  final List<LabeledImage> profileImages;

  const Student({
    required this.fields,
    required this.profileImages,
  });

  @override
  List<Object?> get props => [fields, profileImages];
}