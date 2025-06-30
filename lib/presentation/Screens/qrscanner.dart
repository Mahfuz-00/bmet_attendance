import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Common/Common/Config/Theme/app_colors.dart';
import '../../Core/Core/Navigation/app_router.dart';
import '../../Data/Models/labeled_images.dart';
import '../State Management/attendance_data_provider.dart';
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
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Scan QR Code'),
          actions: [
            IconButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('auth_token');
                await prefs.setBool('is_logged_in', false);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                      (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
            )
          ],
        ),
        body: Stack(
          children: [
            QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: AppColors.accent,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
            if (isProcessing)
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ],
        ),
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
        print('QRScanner: Scanned URL: $url');
        final pdfBytes = await _fetchPdf(url);
        final result = await _extractContentFromPdf(pdfBytes);
        print('QRScanner: Extracted ${result.profileImages.length} images');
        Provider.of<AttendanceDataProvider>(context, listen: false).setAttendanceData(
          extractedFields: result.extractedFields,
          profileImages: result.profileImages,
        );
        print('QRScanner: Navigating to textDisplay');
        Navigator.pushNamed(context, AppRoutes.textDisplay);
      } catch (e) {
        print('QRScanner: Error: $e');
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
    if (response.statusCode == 200 &&
        response.headers['content-type']?.contains('application/pdf') == true) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load PDF or invalid content type');
    }
  }

  Future<ExtractedContent> _extractContentFromPdf(Uint8List pdfBytes) async {
    try {
      String text = '';
      {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp.pdf');
        await tempFile.writeAsBytes(pdfBytes);
        text = await ReadPdfText.getPDFtext(tempFile.path);
        await tempFile.delete();
        print('read_pdf_text output: $text');
      }

      final extractedFields = _extractFieldsFromText(text);

      List<Uint8List> images = [];
      List<String> imageTexts = [];
      List<String> profileDetections = [];
      List<LabeledImage> profileImages = [];
      final pdfDoc = await PdfDocument.openData(pdfBytes);
      print('PDF pages: ${pdfDoc.pagesCount}');
      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i);
        final renderedImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        if (renderedImage?.bytes != null) {
          print('Page $i: Rendered image, bytes: ${renderedImage!.bytes.length}');
          images.add(renderedImage!.bytes);
          final result = await _extractTextFromImage(renderedImage!.bytes, i);
          imageTexts.add(result.text);
          profileDetections.add(result.profileImages.isNotEmpty ? 'Yes' : 'No');
          profileImages.addAll(result.profileImages);
        } else {
          print('Page $i: Failed to render image');
        }
        await page.close();
      }
      await pdfDoc.close();

      print('QRScanner: Total profile images extracted: ${profileImages.length}');
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
    print('Extracted fields: $fields');
    return fields;
  }

  Future<ImageAnalysisResult> _extractTextFromImage(Uint8List imageBytes, int index) async {
    try {
      final image = img.decodePng(imageBytes);
      if (image == null) {
        print('Image $index: Failed to decode image');
        final blankImage = img.Image(width: 100, height: 100);
        img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
        return ImageAnalysisResult(text: 'Failed to decode image', profileImages: [
          LabeledImage(
            label: 'Blank Fallback Image',
            image: img.encodePng(blankImage),
          ),
        ]);
      }

      print('Image $index: Decoded image, width: ${image.width}, height: ${image.height}');

      List<LabeledImage> profileImages = [];
      const profileCropSize = 120;

      // Extract only the first image at (345, 220)
      if (image.width >= profileCropSize && image.height >= profileCropSize) {
        final region = img.copyCrop(image, x: 345, y: 220, width: profileCropSize, height: profileCropSize);
        final regionStats = _computeRegionStats(region);
        print('Image $index: Region at (345, 220) - isPhotoLike: ${regionStats.isPhotoLike}, isColorful: ${regionStats.isColorful}');
        if (regionStats.isPhotoLike || regionStats.isColorful) {
          profileImages.add(LabeledImage(
            label: 'Profile Image',
            image: img.encodePng(region),
          ));
          print('Image $index: Added Profile Image at (345, 220)');
        }
      }

      // Fallback if no image is found
      if (profileImages.isEmpty) {
        final blankImage = img.Image(width: 100, height: 100);
        img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
        profileImages.add(LabeledImage(
          label: 'Blank Fallback Image',
          image: img.encodePng(blankImage),
        ));
        print('Image $index: Added Blank Fallback Image');
      }

      String text = '';
      if (image.textData != null) {
        for (var entry in image.textData!.entries) {
          text += '${entry.key}: ${entry.value}\n';
        }
      }
      print('Image $index: Extracted text: $text, Images: ${profileImages.length}');
      return ImageAnalysisResult(
        text: text.isEmpty ? 'No embedded text found' : text,
        profileImages: profileImages,
      );
    } catch (e) {
      print('Image $index text extraction error: $e');
      final blankImage = img.Image(width: 100, height: 100);
      img.fillRect(blankImage, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 255, 255));
      return ImageAnalysisResult(text: 'Error reading image: $e', profileImages: [
        LabeledImage(
          label: 'Error Fallback Image',
          image: img.encodePng(blankImage),
        ),
      ]);
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

    final isPhotoLike = totalVariance > 300;
    final isColorful = hasColor;

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