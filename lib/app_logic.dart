import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }
}
