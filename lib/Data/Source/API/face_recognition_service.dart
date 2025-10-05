import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// Data class to return embedding and status
class FaceEmbeddingResult {
  final List<double>? embedding;
  final bool isSuccessful;
  final String? errorMessage;

  FaceEmbeddingResult({
    this.embedding,
    required this.isSuccessful,
    this.errorMessage,
  });
}

class FaceRecognitionService {
  Interpreter? _interpreter;
  bool _busy = false;
  bool _ready = false;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );
  final List<Future<FaceEmbeddingResult> Function()> _taskQueue = [];

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      print('FaceRecognitionService: Loading TFLite model...');
      _interpreter = await Interpreter.fromAsset('assets/models/facenet.tflite');
      print('FaceRecognitionService: Model loaded successfully');
      if (_interpreter != null) {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        print('FaceRecognitionService: Input tensor shape: ${inputTensor.shape}');
        print('FaceRecognitionService: Output tensor shape: ${outputTensor.shape}');
        _ready = true;
        print('FaceRecognitionService: Interpreter ready');
      } else {
        print('FaceRecognitionService: Interpreter is null after loading');
      }
    } catch (e, stackTrace) {
      print('FaceRecognitionService: Error loading model: $e');
      print('FaceRecognitionService: Stack trace: $stackTrace');
      throw Exception('Failed to load face recognition model');
    }
  }

  Future<FaceEmbeddingResult> extractFaceEmbedding(Uint8List imageBytes) async {
    print('FaceRecognitionService: Enqueuing face processing, bytes length=${imageBytes.length}');

    // Create a task for processing
    Future<FaceEmbeddingResult> task() async {
      while (!_ready) {
        print('FaceRecognitionService: Waiting for interpreter to be ready...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_interpreter == null) {
        print('FaceRecognitionService: Interpreter is null');
        return FaceEmbeddingResult(
          isSuccessful: false,
          errorMessage: 'Model not initialized',
        );
      }

      _busy = true;
      try {
        // Decode image
        final image = img.decodeImage(imageBytes);
        if (image == null) {
          print('FaceRecognitionService: Failed to decode image');
          return FaceEmbeddingResult(
            isSuccessful: false,
            errorMessage: 'Failed to decode image for embedding',
          );
        }
        print('FaceRecognitionService: Decoded image: width=${image.width}, height=${image.height}');

        // Check brightness
        double brightness = _computeBrightness(image);
        print('FaceRecognitionService: Image brightness: $brightness');
        if (brightness < 50) {
          print('FaceRecognitionService: Image too dark, brightness=$brightness');
          return FaceEmbeddingResult(
            isSuccessful: false,
            errorMessage: 'Image too dark for face recognition',
          );
        }

        // Pre-resize image for face detection
        final targetWidth = 720;
        final targetHeight = (image.height * targetWidth / image.width).round();
        final preResized = img.copyResize(image, width: targetWidth, height: targetHeight);
        final preResizedBytes = img.encodeJpg(preResized, quality: 90);
        print('FaceRecognitionService: Pre-resized image: width=${preResized.width}, height=${preResized.height}');

        // Save to temporary file for ML Kit face detection
        final tempFile = File('${Directory.systemTemp.path}/tmp_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(preResizedBytes);
        final inputImage = InputImage.fromFilePath(tempFile.path);

        // Detect faces
        final faces = await _faceDetector.processImage(inputImage);
        print('FaceRecognitionService: Detected ${faces.length} face(s)');

        if (faces.isEmpty) {
          print('FaceRecognitionService: No face detected');
          await tempFile.delete();
          return FaceEmbeddingResult(
            isSuccessful: false,
            errorMessage: 'No face detected in image',
          );
        }

        final face = faces.first;
        final rect = face.boundingBox;
        print('FaceRecognitionService: Face detected: boundingBox=$rect');

        // Check face size
        final faceWidthPercent = rect.width / preResized.width;
        print('FaceRecognitionService: Face width percent: ${(faceWidthPercent * 100).toStringAsFixed(2)}%');
        if (faceWidthPercent < 0.15 || faceWidthPercent > 0.5) {
          print('FaceRecognitionService: Face size out of range: ${faceWidthPercent * 100}%');
          await tempFile.delete();
          return FaceEmbeddingResult(
            isSuccessful: false,
            errorMessage: 'Face size out of range',
          );
        }

        // Crop face with padding
        final cropX = (rect.left - 50).toInt().clamp(0, preResized.width - 1);
        final cropY = (rect.top - 50).toInt().clamp(0, preResized.height - 1);
        final cropWidth = (rect.width + 100).toInt().clamp(0, preResized.width - cropX);
        final cropHeight = (rect.height + 100).toInt().clamp(0, preResized.height - cropY);
        print('FaceRecognitionService: Cropping: x=$cropX, y=$cropY, width=$cropWidth, height=$cropHeight');

        final cropped = img.copyCrop(preResized, x: cropX, y: cropY, width: cropWidth, height: cropHeight);
        final resized = img.copyResize(cropped, width: 160, height: 160);
        print('FaceRecognitionService: Resized image: width=${resized.width}, height=${resized.height}');

        // Preprocess image
        final input = _preprocessImage(resized);
        print('FaceRecognitionService: Preprocessed image, input shape: [1, 160, 160, 3], first few values: ${input[0][0][0].sublist(0, 3)}');

        // Run inference
        final output = List.filled(512, 0.0).reshape([1, 512]);
        print('FaceRecognitionService: Running inference with input shape: [1, 160, 160, 3]');
        try {
          _interpreter!.run(input, output);
          print('FaceRecognitionService: Inference completed successfully');
        } catch (e, stackTrace) {
          print('FaceRecognitionService: Inference error: $e');
          print('FaceRecognitionService: Stack trace: $stackTrace');
          await tempFile.delete();
          return FaceEmbeddingResult(
            isSuccessful: false,
            errorMessage: 'Failed to run inference: $e',
          );
        }

        // Normalize embedding
        final embedding = _l2Normalize(List<double>.from(output[0]));
        print('FaceRecognitionService: Embedding generated, length=${embedding.length}, first few values: ${embedding.take(10).toList()}');

        await tempFile.delete();
        return FaceEmbeddingResult(
          embedding: embedding,
          isSuccessful: true,
          errorMessage: null,
        );
      } catch (e, stackTrace) {
        print('FaceRecognitionService: Error processing face: $e');
        print('FaceRecognitionService: Stack trace: $stackTrace');
        return FaceEmbeddingResult(
          isSuccessful: false,
          errorMessage: 'Failed to extract face embedding: $e',
        );
      } finally {
        _busy = false;
      }
    }

    // Add task to queue and process sequentially
    _taskQueue.add(task);
    if (_taskQueue.length == 1 && !_busy) {
      while (_taskQueue.isNotEmpty) {
        final currentTask = _taskQueue.first;
        final result = await currentTask();
        _taskQueue.removeAt(0);
        if (result.isSuccessful) {
          return result; // Return successful result
        } else if (_taskQueue.isEmpty) {
          return result; // Return error if no more tasks
        }
      }
    }
    return FaceEmbeddingResult(
      isSuccessful: false,
      errorMessage: 'Processing queued, please wait',
    );
  }

  Future<bool> compareFaces(List<double> embedding1, List<double> embedding2) async {
    print('FaceRecognitionService: Comparing embeddings, length1=${embedding1.length}, length2=${embedding2.length}');
    if (embedding1.length != embedding2.length) {
      print('FaceRecognitionService: Embedding length mismatch: ${embedding1.length} vs ${embedding2.length}');
      return false;
    }

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
      print('FaceRecognitionService: Invalid embedding norms: norm1=$norm1, norm2=$norm2');
      return false;
    }
    final similarity = dotProduct / (norm1 * norm2);
    print('FaceRecognitionService: Cosine similarity: $similarity');
    return similarity > 0.8;
  }

  double _computeBrightness(img.Image image) {
    print('FaceRecognitionService: Computing brightness for image: width=${image.width}, height=${image.height}');
    int totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
        totalBrightness += brightness;
        pixelCount++;
      }
    }

    final averageBrightness = totalBrightness / pixelCount;
    print('FaceRecognitionService: Calculated brightness: $averageBrightness');
    return averageBrightness;
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    print('FaceRecognitionService: Preprocessing image: width=${image.width}, height=${image.height}');
    const mean = 127.5;
    const std = 127.5;

    final data = List.generate(
      1,
          (_) => List.generate(
        160,
            (_) => List.generate(
          160,
              (_) => List.filled(3, 0.0),
        ),
      ),
    );

    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        data[0][y][x][0] = (r - mean) / std;
        data[0][y][x][1] = (g - mean) / std;
        data[0][y][x][2] = (b - mean) / std;
      }
    }
    return data;
  }

  List<double> _l2Normalize(List<double> embedding) {
    print('FaceRecognitionService: Normalizing embedding, length=${embedding.length}');
    final sum = embedding.fold<double>(0.0, (a, b) => a + b * b);
    final norm = sqrt(sum);
    if (norm == 0) {
      print('FaceRecognitionService: Embedding norm is zero, returning original embedding');
      return embedding;
    }
    final normalized = embedding.map((e) => e / norm).toList();
    print('FaceRecognitionService: Normalized embedding, first few values: ${normalized.take(10).toList()}');
    return normalized;
  }

  void dispose() {
    print('FaceRecognitionService: Disposing resources');
    _faceDetector.close();
    _interpreter?.close();
    _busy = false;
    _ready = false;
    _taskQueue.clear();
    print('FaceRecognitionService: Disposed');
  }
}