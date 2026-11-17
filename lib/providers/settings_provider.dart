import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  int _timerDuration = 0; // 0, 3, 5, 10 seconds
  int _gridColumns = 2; // 2 or 3
  double _overlayOpacity = 0.5; // 0.2 to 0.8

  bool get isDarkMode => _isDarkMode;
  int get timerDuration => _timerDuration;
  int get gridColumns => _gridColumns;
  double get overlayOpacity => _overlayOpacity;

  static const List<int> timerOptions = [0, 3, 5, 10];
  static const List<int> gridOptions = [2, 3];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _timerDuration = prefs.getInt('timerDuration') ?? 0;
    _gridColumns = prefs.getInt('gridColumns') ?? 2;
    _overlayOpacity = prefs.getDouble('overlayOpacity') ?? 0.5;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setTimerDuration(int seconds) async {
    if (timerOptions.contains(seconds)) {
      _timerDuration = seconds;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timerDuration', _timerDuration);
    }
  }

  Future<void> setGridColumns(int columns) async {
    if (gridOptions.contains(columns)) {
      _gridColumns = columns;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('gridColumns', _gridColumns);
    }
  }

  Future<void> toggleGridColumns() async {
    _gridColumns = _gridColumns == 2 ? 3 : 2;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gridColumns', _gridColumns);
  }

  Future<void> setOverlayOpacity(double opacity) async {
    _overlayOpacity = opacity.clamp(0.2, 0.8);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('overlayOpacity', _overlayOpacity);
  }
}
