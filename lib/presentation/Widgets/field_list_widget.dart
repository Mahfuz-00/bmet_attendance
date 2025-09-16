import 'package:flutter/material.dart';

class FieldListWidget extends StatelessWidget {
  final List<MapEntry<String, String>> fields;

  const FieldListWidget({Key? key, required this.fields}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: fields.isNotEmpty
          ? fields.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '${entry.key}:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                entry.value,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.left,
                softWrap: true,
              ),
            ),
          ],
        ),
      )).toList()
          : [
        const Text(
          'No fields extracted',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}