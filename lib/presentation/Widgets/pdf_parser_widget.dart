import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:pdfx/pdfx.dart';
import '../../Data/Models/labeled_images.dart';
import 'image_analyzer_widget.dart';

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

class PdfParser {
  // Process PDF in main thread, no compute
  static Future<ExtractedContent> extractContentFromPdf(Uint8List pdfBytes) async {
    print('PDF Parser: Starting PDF processing in main thread');
    try {
      String text = '';
      {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp.pdf');
        await tempFile.writeAsBytes(pdfBytes);
        text = await ReadPdfText.getPDFtext(tempFile.path);
        await tempFile.delete();
        print('PDF Parser: read_pdf_text output: $text');
      }

      final extractedFields = _extractFieldsFromText(text);
      if (extractedFields.isEmpty) {
        throw Exception('Wrong format');
      }

      List<Uint8List> images = [];
      List<String> imageTexts = [];
      List<String> profileDetections = [];
      List<LabeledImage> profileImages = [];
      final pdfDoc = await PdfDocument.openData(pdfBytes);
      print('PDF Parser: PDF pages: ${pdfDoc.pagesCount}');
      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i);
        final renderedImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        if (renderedImage?.bytes != null) {
          print('PDF Parser: Page $i: Rendered image, bytes: ${renderedImage!.bytes.length}');
          images.add(renderedImage!.bytes);
          final result = await ImageAnalyzer.extractTextFromImage(renderedImage!.bytes, i);
          imageTexts.add(result.text);
          profileDetections.add(result.profileImages.isNotEmpty ? 'Yes' : 'No');
          profileImages.addAll(result.profileImages);
        } else {
          print('PDF Parser: Page $i: Failed to render image');
        }
        await page.close();
      }
      await pdfDoc.close();

      print('PDF Parser: Total profile images extracted: ${profileImages.length}');
      return ExtractedContent(
        text: text.isEmpty ? 'No text found in PDF' : text,
        images: images,
        imageTexts: imageTexts,
        profileDetections: profileDetections,
        profileImages: profileImages,
        extractedFields: extractedFields,
      );
    } catch (e) {
      print('PDF Parser: Extraction error: $e');
      throw Exception('Error extracting content: $e');
    }
  }

  static Map<String, String?> _extractFieldsFromText(String text) {
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
      // Skip lines containing "Payment Status" (case-insensitive)
      // if (line.trim().toLowerCase().startsWith('payment status')) continue;
      // cleanedLines.add(line);
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

      String? matchedLabel;
      String? initialValue;

      final horizontalMatch = RegExp(r'^(.+?)\s*[:;=]\s*(.*)$').firstMatch(line);
      if (horizontalMatch != null) {
        final possibleLabel = horizontalMatch.group(1)?.trim();
        matchedLabel = findMatchingLabel(possibleLabel ?? '');
        initialValue = horizontalMatch.group(2)?.trim();
      } else {
        matchedLabel = findMatchingLabel(line);

        if (matchedLabel == null && i + 1 < cleanedLines.length) {
          final combinedLabel = (line + ' ' + cleanedLines[i + 1].trim()).trim();
          matchedLabel = findMatchingLabel(combinedLabel);
          if (matchedLabel != null) {
            i++;
          }
        }
      }

      if (matchedLabel != null) {
        if (currentLabel != null && fields[currentLabel] == null) {
          fields[currentLabel] = buffer.toString().trim();
        }
        currentLabel = matchedLabel;
        buffer.clear();

        if (initialValue != null && initialValue.isNotEmpty) {
          buffer.write(initialValue);
        }
      } else if (currentLabel != null) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line);
      }
    }

    if (currentLabel != null && fields[currentLabel] == null) {
      fields[currentLabel] = buffer.toString().trim();
    }

    final finalFields = <String, String>{};
    fields.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) {
        finalFields[k] = v.trim();
      }
    });

    return finalFields;
  }
}