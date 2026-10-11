import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  static Future<ThemeController> load() async {
    final controller = ThemeController();
    final prefs = await SharedPreferences.getInstance();
    controller._mode = prefs.getBool('darkTheme') == true
        ? ThemeMode.dark : ThemeMode.light;
    return controller;
  }
  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkTheme', isDark);
  }
}
