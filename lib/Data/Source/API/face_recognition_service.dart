import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class FaceRecognitionService {
  Interpreter? _interpreter;

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Load your TensorFlow Lite model (e.g., MobileFaceNet)
      final model = await rootBundle.loadString('assets/models/facenet.tflite');
      _interpreter = await Interpreter.fromAsset(model);
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

    // Preprocess image (adjust based on your model's requirements)
    final inputImage = _preprocessImage(image);

    // Run inference
    if (_interpreter == null) {
      throw Exception('Model not initialized');
    }

    // Example input/output shapes (adjust based on your model)
    var input = [inputImage]; // Shape: [1, height, width, 3]
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]); // Example: 128-dimensional embedding

    _interpreter!.run(input, output);

    return output[0].cast<double>();
  }

  Future<bool> compareFaces(List<double> embedding1, List<double> embedding2) async {
    if (embedding1.length != embedding2.length) {
      return false;
    }

    // Euclidean distance
    double distance = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      distance += pow(embedding1[i] - embedding2[i], 2);
    }
    distance = sqrt(distance);
    return distance < 0.6; // Adjust threshold based on your model
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
    // Resize to model input size (e.g., 112x112 for MobileFaceNet)
    final resized = img.copyResize(image, width: 112, height: 112);

    // Normalize pixel values (adjust based on your model's requirements)
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
              // Normalize to [-1, 1] or [0, 1] based on model
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