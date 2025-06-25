import 'package:flutter/material.dart';

import '../../Data/Models/labeled_images.dart';

class AttendanceDataProvider with ChangeNotifier {
  Map<String, String> _extractedFields = {};
  List<LabeledImage> _profileImages = [];

  Map<String, String> get extractedFields => _extractedFields;
  List<LabeledImage> get profileImages => _profileImages;

  void setAttendanceData({
    required Map<String, String> extractedFields,
    required List<LabeledImage> profileImages,
  }) {
    _extractedFields = extractedFields;
    _profileImages = profileImages;
    notifyListeners();
    print('AttendanceDataProvider: Set data - Fields: ${_extractedFields.length}, Images: ${_profileImages.length}');
  }

  void clearData() {
    _extractedFields = {};
    _profileImages = [];
    notifyListeners();
    print('AttendanceDataProvider: Cleared data');
  }
}