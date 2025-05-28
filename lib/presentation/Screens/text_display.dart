import 'package:flutter/material.dart';

class TextDisplayScreen extends StatelessWidget {
  final String text;

  const TextDisplayScreen({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extracted Text')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            text.isEmpty ? 'No text found in PDF' : text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}