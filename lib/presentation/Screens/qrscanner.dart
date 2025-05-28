import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'text_display.dart';

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
      controller.pauseCamera(); // Pause scanning to prevent multiple scans
      try {
        String url = scanData.code!;
        final pdfBytes = await _fetchPdf(url);
        final text = await _extractTextFromPdf(pdfBytes);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TextDisplayScreen(text: text),
          ),
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

  Future<String> _extractTextFromPdf(Uint8List pdfBytes) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp.pdf');

      // Write PDF bytes to temporary file
      await tempFile.writeAsBytes(pdfBytes);

      // Extract text using read_pdf_text
      final text = await ReadPdfText.getPDFtext(tempFile.path);

      // Delete temporary file to keep process hidden
      await tempFile.delete();

      return text.isEmpty ? 'No text found in PDF' : text;
    } catch (e) {
      throw Exception('Error extracting text: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}