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
    final size = MediaQuery.of(context).size;
    final cutOutSize = size.width * 0.8;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Scan QR Code'),
          actions: [
            IconButton(
              onPressed: () {
                controller?.toggleFlash();
                setState(() {}); // Update UI if torch state changes
              },
              icon: FutureBuilder<bool?>(
                future: controller?.getFlashStatus(),
                builder: (context, snapshot) {
                  return Icon(snapshot.data == true ? Icons.flash_on : Icons.flash_off);
                },
              ),
            ),
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
                borderRadius: 12,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: cutOutSize,
                overlayColor: Colors.black.withOpacity(0.6),
              ),
            ),
            // Center(
            //   child: Container(
            //     // width: 320,
            //     // height: 320,
            //     // decoration: BoxDecoration(
            //     //   border: Border.all(color: AppColors.accent, width: 8),
            //     //   borderRadius: BorderRadius.circular(12),
            //     // ),
            //     child: const Center(
            //       child: Text(
            //         'Align QR code within the frame',
            //         style: TextStyle(color: Colors.white, fontSize: 16),
            //         textAlign: TextAlign.center,
            //       ),
            //     ),
            //   ),
            // ),
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
    }, onError: (error) {
      print('QRScanner: Stream error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Scanner error: $error')),
      );
      setState(() {
        isProcessing = false;
      });
    });
    // Log camera status
    controller.getCameraInfo().then((cameraInfo) {
      print('QRScanner: Camera info: $cameraInfo');
    });
    controller.getFlashStatus().then((flashStatus) {
      print('QRScanner: Flash status: $flashStatus');
    });
    // Check permissions
    // controller.hasPermissions().then((hasPermission) {
    //   print('QRScanner: Camera permission: $hasPermission');
    //   if (!hasPermission) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Camera permission denied')),
    //     );
    //   }
    // });
  }

  Future<Uint8List> _fetchPdf(String url) async {
    print('URL : $url');
    final response = await http.get(Uri.parse(url));
    print('Response Body: ${response.body}');
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
      if (extractedFields.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong format')),
        );
        controller?.resumeCamera();
        setState(() => isProcessing = false);
      }

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

  Map<String, String?> _extractFieldsFromText(String text) {
    final fields = <String, String?>{};

    const validLabels = [
      'Name',
      "Father's Name",
      'Father Name',
      "Mother's Name",
      'Mother Name',
      'NID / Birth Reg. No.',
      'NID',
      'Birth Reg. No.',
      'Birth Reg No',
      'Passport No',
      'Destination Country',
      'Room No',
      'Student ID',
      'Roll No',
      'Batch Name (Code)',
      'Batch Code',
      'Batch No',
      'Venue / Institute',
      'Venue',
      'Institute Name',
      'Course Date',
      'Course Time',
    ];

    for (var label in validLabels) {
      fields[label] = null;
    }

    final lines = text
        .split('\n')
        .where((line) => !line.trim().startsWith('PDO Enrollment Card'))
        .toList();

    final cleanedLines = <String>[];
    for (var line in lines) {
      if (line.trim().toLowerCase().startsWith('verify this card')) break;
      cleanedLines.add(line);
    }

    String? findMatchingLabel(String line) {
      final normalizedLine = line.toLowerCase().replaceAll(RegExp(r'[.:/()\s]+'), '');
      for (var label in validLabels) {
        final normalizedLabel = label.toLowerCase().replaceAll(RegExp(r'[.:/()\s]+'), '');
        if (normalizedLine == normalizedLabel || normalizedLine.startsWith(normalizedLabel)) {
          if (label == 'Batch Code' || label == 'Batch Name (Code)') {
            return 'Batch No';
          }
          return label;
        }
      }
      return null;
    }

    String? currentLabel;
    final buffer = StringBuffer();

    for (int i = 0; i < cleanedLines.length; i++) {
      final line = cleanedLines[i].trim();

      // Try two-line label detection:
      String? matchedLabel;
      String? initialValue;

      // 1. Check if line has horizontal label:value pattern
      final horizontalMatch = RegExp(r'^(.+?)\s*[:;=]\s*(.*)$').firstMatch(line);
      if (horizontalMatch != null) {
        final possibleLabel = horizontalMatch.group(1)?.trim();
        matchedLabel = findMatchingLabel(possibleLabel ?? '');
        initialValue = horizontalMatch.group(2)?.trim();
      } else {
        // 2. If no horizontal match, try single line label
        matchedLabel = findMatchingLabel(line);

        // 3. If still no label and next line exists, try two-line label:
        if (matchedLabel == null && i + 1 < cleanedLines.length) {
          final combinedLabel = (line + ' ' + cleanedLines[i + 1].trim()).trim();
          matchedLabel = findMatchingLabel(combinedLabel);
          if (matchedLabel != null) {
            i++; // consume next line as label line
          }
        }
      }

      if (matchedLabel != null) {
        // Save previous label's buffered value
        if (currentLabel != null && fields[currentLabel] == null) {
          fields[currentLabel] = buffer.toString().trim();
        }
        // Start new label & clear buffer
        currentLabel = matchedLabel;
        buffer.clear();

        if (initialValue != null && initialValue.isNotEmpty) {
          buffer.write(initialValue);
        }
      } else if (currentLabel != null) {
        // Append current line to current label's value buffer
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line);
      }
    }

    // Save last label's buffer
    if (currentLabel != null && fields[currentLabel] == null) {
      fields[currentLabel] = buffer.toString().trim();
    }

    // Remove null or empty fields
    final finalFields = <String, String>{};
    fields.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) {
        finalFields[k] = v.trim();
      }
    });

    return finalFields;
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
  final Map<String, String?> extractedFields;

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