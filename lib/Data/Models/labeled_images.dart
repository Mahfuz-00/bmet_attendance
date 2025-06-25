import 'dart:typed_data';

class LabeledImage {
  final String label;
  final Uint8List image;

  LabeledImage({required this.label, required this.image});
}