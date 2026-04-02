import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final _service = SettingsService();
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> load() async {
    _settings = await _service.load();
    notifyListeners();
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    await _service.save(_settings);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings.themeMode = mode;
    await _service.save(_settings);
    notifyListeners();
  }
}
