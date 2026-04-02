import 'package:flutter/material.dart';

class AppSettings {
  int maxConcurrentDevices;
  int devicePollIntervalMs;
  String logsDirectory;
  String platformToolsPath;
  ThemeMode themeMode;

  AppSettings({
    this.maxConcurrentDevices = 3,
    this.devicePollIntervalMs = 5000,
    this.logsDirectory = '',
    this.platformToolsPath = '',
    this.themeMode = ThemeMode.system,
  });
}
