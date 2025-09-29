import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../Data/Models/labeled_images.dart';

class ImageAnalysisResult {
  final String text;
  final List<LabeledImage> profileImages;

  ImageAnalysisResult({
    required this.text,
    required this.profileImages,
  });
}

class RegionStats {
  final bool isPhotoLike;
  final bool isColorful;

  RegionStats({required this.isPhotoLike, required this.isColorful});
}

class ImageAnalyzer {
  static Future<ImageAnalysisResult> extractTextFromImage(Uint8List imageBytes, int index) async {
    try {
      final image = img.decodePng(imageBytes);
      if (image == null) {
        print('Image Analyzer: Image $index: Failed to decode image');
        final blankImage = img.Image(width: 100, height: 100);
        img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
        return ImageAnalysisResult(
          text: 'Failed to decode image',
          profileImages: [
            LabeledImage(
              label: 'Blank Fallback Image',
              image: img.encodePng(blankImage),
            ),
          ],
        );
      }

      print('Image Analyzer: Image $index: Decoded image, width: ${image.width}, height: ${image.height}');

      List<LabeledImage> profileImages = [];
      const profileCropSize = 120;

      if (image.width >= profileCropSize && image.height >= profileCropSize) {
        final region = img.copyCrop(image, x: 345, y: 220, width: profileCropSize, height: profileCropSize);
        final regionStats = _computeRegionStats(region);
        print('Image Analyzer: Image $index: Region at (345, 220) - isPhotoLike: ${regionStats.isPhotoLike}, isColorful: ${regionStats.isColorful}');
        if (regionStats.isPhotoLike || regionStats.isColorful) {
          profileImages.add(LabeledImage(
            label: 'Profile Image',
            image: img.encodePng(region),
          ));
          print('Image Analyzer: Image $index: Added Profile Image at (345, 220)');
        }
      }

      if (profileImages.isEmpty) {
        final blankImage = img.Image(width: 100, height: 100);
        img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
        profileImages.add(LabeledImage(
          label: 'Blank Fallback Image',
          image: img.encodePng(blankImage),
        ));
        print('Image Analyzer: Image $index: Added Blank Fallback Image');
      }

      String text = '';
      if (image.textData != null) {
        for (var entry in image.textData!.entries) {
          text += '${entry.key}: ${entry.value}\n';
        }
      }
      print('Image Analyzer: Image $index: Extracted text: $text, Images: ${profileImages.length}');
      return ImageAnalysisResult(
        text: text.isEmpty ? 'No embedded text found' : text,
        profileImages: profileImages,
      );
    } catch (e) {
      print('Image Analyzer: Image $index text extraction error: $e');
      final blankImage = img.Image(width: 100, height: 100);
      img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
      return ImageAnalysisResult(
        text: 'Error reading image: $e',
        profileImages: [
          LabeledImage(
            label: 'Error Fallback Image',
            image: img.encodePng(blankImage),
          ),
        ],
      );
    }
  }

  static RegionStats _computeRegionStats(img.Image region) {
    int rSum = 0, gSum = 0, bSum = 0;
    int r2Sum = 0, g2Sum = 0, b2Sum = 0;
    int count = 0;
    bool hasColor = false;

    for (int y = 0; y < region.height; y++) {
      for (int x = 0; x < region.width; x++) {
        final pixel = region.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        rSum += r;
        gSum += g;
        bSum += b;
        r2Sum += r * r;
        g2Sum += g * g;
        b2Sum += b * b;
        count++;
        if ((r - g).abs() > 15 || (g - b).abs() > 15 || (r - b).abs() > 15) {
          hasColor = true;
        }
      }
    }

    final rMean = rSum / count;
    final gMean = gSum / count;
    final bMean = bSum / count;
    final rVariance = (r2Sum / count - rMean * rMean).abs();
    final gVariance = (g2Sum / count - gMean * gMean).abs();
    final bVariance = (b2Sum / count - bMean * bMean).abs();
    final isPhotoLike = rVariance > 1000 || gVariance > 1000 || bVariance > 1000;

    return RegionStats(isPhotoLike: isPhotoLike, isColorful: hasColor);
  }
}