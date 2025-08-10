// lib/notifiers/font_size_notifier.dart
import 'package:flutter/material.dart';

class FontSizeNotifier extends ChangeNotifier {
  double _fontSize = 16.0;

  double get fontSize => _fontSize;
  double get fontSizeFactor => _fontSize / 16.0;

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }
}