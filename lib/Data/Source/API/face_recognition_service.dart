import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';

class FaceRecognitionService {
  Interpreter? _interpreter;

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/facenet.tflite');
      print('FaceRecognitionService: Model loaded successfully');
    } catch (e) {
      print('FaceRecognitionService: Error loading model: $e');
      throw Exception('Failed to load face recognition model');
    }
  }

  Future<List<double>> extractFaceEmbedding(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image for embedding');
    }

    // Validate lighting
    double brightness = _computeBrightness(image);
    if (brightness < 50) {
      throw Exception('Image too dark for face recognition');
    }

    // Preprocess image
    final inputImage = _preprocessImage(image);

    // Run inference
    if (_interpreter == null) {
      throw Exception('Model not initialized');
    }

    var input = [inputImage]; // Shape: [1, 112, 112, 3]
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]); // 128-dimensional embedding

    _interpreter!.run(input, output);

    return output[0].cast<double>();
  }

  Future<bool> compareFaces(List<double> embedding1, List<double> embedding2) async {
    if (embedding1.length != embedding2.length) {
      return false;
    }

    // Cosine similarity
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    norm1 = sqrt(norm1);
    norm2 = sqrt(norm2);
    if (norm1 == 0 || norm2 == 0) {
      return false;
    }
    final similarity = dotProduct / (norm1 * norm2);
    print('FaceRecognitionService: Cosine similarity: $similarity');
    return similarity > 0.8; // Your specified threshold
  }

  double _computeBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
        totalBrightness += brightness;
        pixelCount++;
      }
    }

    return totalBrightness / pixelCount;
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: 112, height: 112);
    final input = List.generate(
      1,
          (_) => List.generate(
        112,
            (y) => List.generate(
          112,
              (x) => List.generate(
            3,
                (c) {
              final pixel = resized.getPixel(x, y);
              return (c == 0 ? pixel.r : c == 1 ? pixel.g : pixel.b) / 255.0;
            },
          ),
        ),
      ),
    );
    return input;
  }

  void dispose() {
    _interpreter?.close();
  }
}