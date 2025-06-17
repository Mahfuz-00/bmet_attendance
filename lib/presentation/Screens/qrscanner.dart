import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import '../../Core/Core/Navigation/app_router.dart';
import 'text_display.dart';
import 'package:image/image.dart' as img;

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
          if (isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (isProcessing) return;
      setState(() {
        isProcessing = true;
      });
      controller.pauseCamera();
      try {
        String url = scanData.code!;
        final pdfBytes = await _fetchPdf(url);
        final result = await _extractContentFromPdf(pdfBytes);
        Navigator.pushNamed(
          context,
          AppRoutes.textDisplay,
          arguments: {
            'text': result.text,
            'images': result.images,
            'imageTexts': result.imageTexts,
            'profileDetections': result.profileDetections,
            'profileImages': result.profileImages,
            'extractedFields': result.extractedFields,
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        controller.resumeCamera();
        setState(() {
          isProcessing = false;
        });
      }
    });
  }

  Future<Uint8List> _fetchPdf(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200 && response.headers['content-type']?.contains('application/pdf') == true) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load PDF or invalid content type');
    }
  }

  Future<ExtractedContent> _extractContentFromPdf(Uint8List pdfBytes) async {
    try {
      // --- Text Extraction with read_pdf_text ---
      String text = '';
      {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp.pdf');
        await tempFile.writeAsBytes(pdfBytes);
        text = await ReadPdfText.getPDFtext(tempFile.path);
        await tempFile.delete();
        print('read_pdf_text output: $text');
      }

      // --- Extract Specific Fields ---
      final extractedFields = _extractFieldsFromText(text);

      // --- Image Extraction with pdfx ---
      List<Uint8List> images = [];
      List<String> imageTexts = [];
      List<String> profileDetections = [];
      List<LabeledImage> profileImages = [];
      {
        final pdfDoc = await PdfDocument.openData(pdfBytes);
        for (int i = 1; i <= pdfDoc.pagesCount; i++) {
          final page = await pdfDoc.getPage(i);
          final renderedImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          if (renderedImage?.bytes != null) {
            images.add(renderedImage!.bytes);
            final result = await _extractTextFromImage(renderedImage!.bytes, i);
            imageTexts.add(result.text);
            profileDetections.add(result.profileImages.isNotEmpty ? 'Yes' : 'No');
            profileImages.addAll(result.profileImages);
          }
          await page.close();
        }
        await pdfDoc.close();
      }

      return ExtractedContent(
        text: text.isEmpty ? 'No text found in PDF' : text,
        images: images,
        imageTexts: imageTexts,
        profileDetections: profileDetections,
        profileImages: profileImages,
        extractedFields: extractedFields,
      );
    } catch (e) {
      print('Extraction error: $e');
      throw Exception('Error extracting content: $e');
    }
  }

  Map<String, String> _extractFieldsFromText(String text) {
    final Map<String, String> patterns = {
      'Name': r'Name[:\s]*(.+?)(?:\n|$)',
      "Father's Name": r"Father's Name[:\s]*(.+?)(?:\n|$)",
      "Mother's Name": r"Mother's Name[:\s]*(.+?)(?:\n|$)",
      'Passport No': r'Passport No[:\s]*(.+?)(?:\n|$)',
      'Destination Country': r'Destination Country[:\s]*(.+?)(?:\n|$)',
      'Batch No': r'Batch No[:\s]*(.+?)(?:\n|$)',
      'Room No': r'Room No[:\s]*(.+?)(?:\n|$)',
      'Student ID': r'Student ID[:\s]*(.+?)(?:\n|$)',
      'Roll No': r'Roll No[:\s]*(.+?)(?:\n|$)',
      'Venue / Institute': r'Venue / Institute[:\s]*(.+?)(?:\n|$)',
      'Course Date': r'Course Date[:\s]*(.+?)(?:\n|$)',
      'Course Time': r'Course Time[:\s]*(.+?)(?:\n|$)',
    };

    final fields = <String, String>{};
    for (var entry in patterns.entries) {
      final match = RegExp(entry.value, caseSensitive: false).firstMatch(text);
      fields[entry.key] = match?.group(1)?.trim() ?? 'Not found';
    }

    return fields;
  }

  Future<ImageAnalysisResult> _extractTextFromImage(Uint8List imageBytes, int index) async {
    try {
      final image = img.decodePng(imageBytes);
      if (image == null) {
        print('Image $index: Failed to decode image');
        return ImageAnalysisResult(text: 'Failed to decode image', profileImages: []);
      }

      // Analyze image for up to three unique colorful regions
      final width = image.width;
      final height = image.height;
      List<LabeledImage> profileImages = [];
      List<Rect> selectedRegions = [];
      const profileCropSize = 120; // Larger for profile photo
      const iconCropSize = 77; // Smaller for icons
      const step = 50; // Sliding window step
      const minDistance = 100; // Minimum distance between regions
      int imageCount = 0;

      // First: Try profile photo near (345, 220)
          {
        const x = 345;
        const y = 220;
        if (x >= 0 && x <= width - profileCropSize && y >= 0 && y <= height - profileCropSize) {
          final region = img.copyCrop(image, x: x, y: y, width: profileCropSize, height: profileCropSize);
          final regionStats = _computeRegionStats(region);
          if (regionStats.isPhotoLike && regionStats.isColorful) {
            imageCount++;
            profileImages.add(LabeledImage(
              label: 'Image $imageCount',
              image: img.encodePng(region),
            ));
            selectedRegions.add(Rect(x: x, y: y, width: profileCropSize, height: profileCropSize));
            print('Image $index: Found ${'Image $imageCount'} at ($x, $y), size: $profileCropSize x $profileCropSize');
          }
        }
      }

      // Second: Scan top-right for other regions
      if (imageCount < 3) {
        for (int y = 0; y < height ~/ 2 && imageCount < 3; y += step) {
          for (int x = width ~/ 2; x < width - iconCropSize && imageCount < 3; x += step) {
            bool overlaps = false;
            final newRect = Rect(x: x, y: y, width: iconCropSize, height: iconCropSize);
            for (var rect in selectedRegions) {
              if (_rectsOverlap(newRect, rect, minDistance)) {
                overlaps = true;
                break;
              }
            }
            if (overlaps) continue;

            final region = img.copyCrop(image, x: x, y: y, width: iconCropSize, height: iconCropSize);
            final regionStats = _computeRegionStats(region);
            if (regionStats.isPhotoLike && regionStats.isColorful) {
              imageCount++;
              profileImages.add(LabeledImage(
                label: 'Image $imageCount',
                image: img.encodePng(region),
              ));
              selectedRegions.add(newRect);
              print('Image $index: Found ${'Image $imageCount'} at ($x, $y), size: $iconCropSize x $iconCropSize');
            }
          }
        }
      }

      // Third: Scan top-left if needed
      if (imageCount < 3) {
        for (int y = 0; y < height ~/ 2 && imageCount < 3; y += step) {
          for (int x = 0; x < width ~/ 2 - iconCropSize && imageCount < 3; x += step) {
            bool overlaps = false;
            final newRect = Rect(x: x, y: y, width: iconCropSize, height: iconCropSize);
            for (var rect in selectedRegions) {
              if (_rectsOverlap(newRect, rect, minDistance)) {
                overlaps = true;
                break;
              }
            }
            if (overlaps) continue;

            final region = img.copyCrop(image, x: x, y: y, width: iconCropSize, height: iconCropSize);
            final regionStats = _computeRegionStats(region);
            if (regionStats.isPhotoLike && regionStats.isColorful) {
              imageCount++;
              profileImages.add(LabeledImage(
                label: 'Image $imageCount',
                image: img.encodePng(region),
              ));
              selectedRegions.add(newRect);
              print('Image $index: Found ${'Image $imageCount'} at ($x, $y), size: $iconCropSize x $iconCropSize');
            }
          }
        }
      }

      // Fallback if still fewer than 3
      if (imageCount < 3) {
        const fallbackSize = 100;
        int fallbackX = 50;
        int fallbackY = 50;
        bool overlaps;
        do {
          overlaps = false;
          final newRect = Rect(x: fallbackX, y: fallbackY, width: fallbackSize, height: fallbackSize);
          for (var rect in selectedRegions) {
            if (_rectsOverlap(newRect, rect, minDistance)) {
              overlaps = true;
              fallbackX += minDistance;
              break;
            }
          }
        } while (overlaps && fallbackX < width - fallbackSize && fallbackY < height - fallbackSize);
        final fallbackRegion = img.copyCrop(image, x: fallbackX, y: fallbackY, width: fallbackSize, height: fallbackSize);
        imageCount++;
        profileImages.add(LabeledImage(
          label: 'Image $imageCount (Fallback)',
          image: img.encodePng(fallbackRegion),
        ));
        print('Image $index: Added ${'Image $imageCount'} (Fallback) at ($fallbackX, $fallbackY), size: $fallbackSize x $fallbackSize');
      }

      String text = '';
      if (image.textData != null) {
        for (var entry in image.textData!.entries) {
          text += '${entry.key}: ${entry.value}\n';
        }
      }
      return ImageAnalysisResult(
        text: text.isEmpty ? 'No embedded text found' : text,
        profileImages: profileImages,
      );
    } catch (e) {
      print('Image $index text extraction error: $e');
      return ImageAnalysisResult(text: 'Error reading image: $e', profileImages: []);
    }
  }

  bool _rectsOverlap(Rect rect1, Rect rect2, int minDistance) {
    final dx = (rect1.x - rect2.x).abs();
    final dy = (rect1.y - rect2.y).abs();
    return dx < rect1.width + minDistance && dy < rect1.height + minDistance;
  }

  RegionStats _computeRegionStats(img.Image region) {
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

        // Relaxed color check
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
    final totalVariance = rVariance + gVariance + bVariance;

    final isPhotoLike = totalVariance > 500; // Relaxed for sensitivity
    final isColorful = hasColor && (rMean > 20 && gMean > 20 && bMean > 20) && (rMean < 235 && gMean < 235 && bMean < 235);

    return RegionStats(isPhotoLike: isPhotoLike, isColorful: isColorful);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

class ExtractedContent {
  final String text;
  final List<Uint8List> images;
  final List<String> imageTexts;
  final List<String> profileDetections;
  final List<LabeledImage> profileImages;
  final Map<String, String> extractedFields;

  ExtractedContent({
    required this.text,
    required this.images,
    required this.imageTexts,
    required this.profileDetections,
    required this.profileImages,
    required this.extractedFields,
  });
}

class ImageAnalysisResult {
  final String text;
  final List<LabeledImage> profileImages;

  ImageAnalysisResult({
    required this.text,
    required this.profileImages,
  });
}

class LabeledImage {
  final String label;
  final Uint8List image;

  LabeledImage({required this.label, required this.image});
}

class RegionStats {
  final bool isPhotoLike;
  final bool isColorful;

  RegionStats({required this.isPhotoLike, required this.isColorful});
}

class Rect {
  final int x;
  final int y;
  final int width;
  final int height;

  Rect({required this.x, required this.y, required this.width, required this.height});
}