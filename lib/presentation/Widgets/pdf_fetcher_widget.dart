import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'pdf_parser_widget.dart';

class PdfFetcher {
  // Process PDF, fetching bytes and delegating parsing
  static Future<ExtractedContent> processPdf(String url) async {
    print('PDF Fetcher: Processing URL: $url');
    final client = http.Client();
    try {
      final pdfBytes = await _fetchPdf(url, client);
      // Delegate parsing to PdfParser, no compute
      return await PdfParser.extractContentFromPdf(pdfBytes);
    } finally {
      client.close();
    }
  }

  static Future<Uint8List> _fetchPdf(String url, http.Client client) async {
    print('PDF Fetcher: Fetching URL: $url');
    try {
      final response = await client.get(Uri.parse(url));
      print('PDF Fetcher: Response Status: ${response.statusCode}, Content-Type: ${response.headers['content-type']}');
      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('application/pdf') == true) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load PDF or invalid content type: ${response.statusCode}');
      }
    } catch (e) {
      print('PDF Fetcher: Error: $e');
      throw Exception('Failed to fetch PDF: $e');
    }
  }
}