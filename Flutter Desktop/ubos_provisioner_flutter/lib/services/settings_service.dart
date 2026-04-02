import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _keyMaxConcurrent = 'max_concurrent';
  static const _keyPollInterval = 'poll_interval';
  static const _keyLogsDir = 'logs_dir';
  static const _keyPlatformTools = 'platform_tools';
  static const _keyTheme = 'theme_mode';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      maxConcurrentDevices: prefs.getInt(_keyMaxConcurrent) ?? 3,
      devicePollIntervalMs: prefs.getInt(_keyPollInterval) ?? 5000,
      logsDirectory: prefs.getString(_keyLogsDir) ?? '',
      platformToolsPath: prefs.getString(_keyPlatformTools) ?? '',
      themeMode: ThemeMode.values[prefs.getInt(_keyTheme) ?? 0],
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxConcurrent, settings.maxConcurrentDevices);
    await prefs.setInt(_keyPollInterval, settings.devicePollIntervalMs);
    await prefs.setString(_keyLogsDir, settings.logsDirectory);
    await prefs.setString(_keyPlatformTools, settings.platformToolsPath);
    await prefs.setInt(_keyTheme, settings.themeMode.index);
  }
}
