import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/device_info.dart';
import '../models/log_entry.dart';
import '../models/provisioning_config.dart';
import '../models/audit_result.dart';
import '../services/adb_service.dart';
import '../services/reporting_service.dart';
import '../providers/settings_provider.dart';

enum OperationStatus { idle, provisioning, deprovisioning, auditing }

class AppState extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  late AdbService _adb;
  final _reporting = ReportingService();

  List<DeviceInfo> _devices = [];
  final List<LogEntry> _logs = [];
  bool _isPolling = false;
  OperationStatus _status = OperationStatus.idle;
  AuditResult? _lastAudit;
  Timer? _pollTimer;
  bool _cancelRequested = false;

  List<DeviceInfo> get devices => List.unmodifiable(_devices);
  List<LogEntry> get logs => List.unmodifiable(_logs);
  bool get isPolling => _isPolling;
  OperationStatus get status => _status;
  AuditResult? get lastAudit => _lastAudit;
  bool get isRunning => _status != OperationStatus.idle;

  AppState(this._settingsProvider, {bool autoStart = true}) {
    _initAdb();
    _settingsProvider.addListener(_initAdb);
    if (autoStart) {
      // Auto-refresh once on startup, then begin polling
      Future.microtask(() async {
        await refreshDevices();
        startPolling();
      });
    }
  }

  void _initAdb() {
    final path = AdbService.resolveAdbPath(_settingsProvider.settings.platformToolsPath);
    _adb = AdbService(path);
  }

  void updateSettings(SettingsProvider sp) {
    _initAdb();
    // Restart polling with potentially new interval
    if (_isPolling) {
      stopPolling();
      startPolling();
    }
  }

  void _log(String deviceSerial, LogSeverity severity, String message) {
    _logs.add(LogEntry(
      timestamp: DateTime.now(),
      deviceSerial: deviceSerial,
      severity: severity,
      message: message,
    ));
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ─── Device Discovery ─────────────────────────────────────────────────────

  Future<void> refreshDevices() async {
    final fresh = await _adb.getConnectedDevicesAsync();

    final prevSerials = _devices.map((d) => d.serial).toSet();
    final freshSerials = fresh.map((d) => d.serial).toSet();

    final added = freshSerials.difference(prevSerials);
    final removed = prevSerials.difference(freshSerials);

    // Preserve selection and known properties for devices still present
    final Map<String, bool> prevSelected = {for (final d in _devices) d.serial: d.isSelected};
    final Map<String, DeviceInfo> prevDevices = {for (final d in _devices) d.serial: d};

    final authorizedNow = <String>{};

    for (final d in fresh) {
      if (prevSelected.containsKey(d.serial)) {
        d.isSelected = prevSelected[d.serial]!;
      }
      if (prevDevices.containsKey(d.serial) && d.status == DeviceStatus.ready) {
        final prev = prevDevices[d.serial]!;

        // Track status transition: unauthorized/offline -> ready.
        if (prev.status != DeviceStatus.ready) {
          authorizedNow.add(d.serial);
        }

        if (prev.model != 'Unknown') {
          d.model = prev.model;
          d.androidVersion = prev.androidVersion;
          d.batteryLevel = prev.batteryLevel;
          d.storageFree = prev.storageFree;
          d.googleAccountStatus = prev.googleAccountStatus;
        }
      }
    }

    _devices = fresh;
    notifyListeners();

    // Only log on actual changes
    for (final serial in added) {
      _log(serial, LogSeverity.ok, 'Device connected.');
    }
    for (final serial in authorizedNow) {
      _log(serial, LogSeverity.ok, 'USB debugging authorized. Loading device details...');
    }
    for (final serial in removed) {
      _log(serial, LogSeverity.warn, 'Device disconnected.');
    }

    // Load properties for:
    // 1) newly connected ready devices,
    // 2) devices that just became authorized,
    // 3) ready devices that still have unknown details (retry path).
    for (final d in _devices) {
      final shouldLoad = d.status == DeviceStatus.ready &&
          (added.contains(d.serial) ||
              authorizedNow.contains(d.serial) ||
              d.model == 'Unknown' ||
              d.batteryLevel.isEmpty ||
              d.storageFree.isEmpty ||
              d.googleAccountStatus == 'Unknown');

      if (shouldLoad) {
        await _adb.loadDeviceProperties(d);
        notifyListeners();
      }
    }
  }

  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    final interval = _settingsProvider.settings.devicePollIntervalMs;
    _pollTimer = Timer.periodic(Duration(milliseconds: interval), (_) => refreshDevices());
    notifyListeners();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    notifyListeners();
  }

  void toggleDeviceSelection(String serial) {
    final idx = _devices.indexWhere((d) => d.serial == serial);
    if (idx >= 0) {
      _devices[idx].isSelected = !_devices[idx].isSelected;
      notifyListeners();
    }
  }

  void selectAll(bool selected) {
    for (final d in _devices) {
      d.isSelected = selected;
    }
    notifyListeners();
  }

  // ─── Provisioning ─────────────────────────────────────────────────────────

  Future<void> startProvisioning(ProvisioningConfig config) async {
    final selected = _devices.where((d) => d.isSelected && d.status == DeviceStatus.ready).toList();
    if (selected.isEmpty) {
      _log('system', LogSeverity.warn, 'No ready devices selected.');
      return;
    }
    _status = OperationStatus.provisioning;
    _cancelRequested = false;
    notifyListeners();

    _log('system', LogSeverity.info, 'Starting provisioning for ${selected.length} device(s)...');

    // Concurrency control using a semaphore pattern with futures
    final semaphore = _Semaphore(config.maxParallel.clamp(1, 10));

    // Get TPK files list for distribution
    List<FileSystemEntity> tpkFiles = [];
    if (config.tpkFolder.isNotEmpty) {
      final dir = Directory(config.tpkFolder);
      if (await dir.exists()) {
        tpkFiles = dir.listSync().where((f) => f.path.toLowerCase().endsWith('.tpk')).toList();
      }
    }

    final futures = <Future>[];
    for (int i = 0; i < selected.length; i++) {
      final device = selected[i];
      final deviceIndex = i;
      futures.add(semaphore.run(() async {
        if (_cancelRequested) return;
        await _provisionDevice(device, config, tpkFiles, deviceIndex);
      }));
    }

    await Future.wait(futures);

    _status = OperationStatus.idle;
    notifyListeners();
    _log('system', LogSeverity.info, 'Provisioning complete.');

    // Export report
    final logsDir = _settingsProvider.settings.logsDirectory;
    try {
      final path = await _reporting.exportProvisioningCsv(
        logsDir.isNotEmpty ? logsDir : 'Logs',
        _logs,
      );
      _log('system', LogSeverity.ok, 'Report saved: $path');
    } catch (e) {
      _log('system', LogSeverity.warn, 'Could not save report: $e');
    }
  }

  Future<void> _provisionDevice(DeviceInfo device, ProvisioningConfig config,
      List<FileSystemEntity> tpkFiles, int deviceIndex) async {
    device.status = DeviceStatus.busy;
    device.progress = 0.0;
    notifyListeners();

    final totalSteps = config.apkPaths.length +
        (config.appDataFolder.isNotEmpty ? 1 : 0) +
        (tpkFiles.isNotEmpty ? 1 : 0);
    int completedSteps = 0;

    void updateProgress(String step) {
      device.currentStep = step;
      device.progress = totalSteps > 0 ? completedSteps / totalSteps : 0;
      notifyListeners();
    }

    // Install APKs
    for (final apkPath in config.apkPaths) {
      if (_cancelRequested) break;
      final apkName = p.basename(apkPath);
      updateProgress('Installing $apkName');
      _log(device.serial, LogSeverity.info, 'Installing $apkName...');
      final result = await _adb.installApk(device.serial, apkPath);
      completedSteps++;
      if (result.isSuccess || result.output.contains('Success')) {
        _log(device.serial, LogSeverity.ok, 'Installed $apkName');
      } else {
        _log(device.serial, LogSeverity.error, 'Failed to install $apkName: ${result.error}');
      }
    }

    // Push app data folder
    if (config.appDataFolder.isNotEmpty && !_cancelRequested) {
      updateProgress('Pushing app data...');
      _log(device.serial, LogSeverity.info, 'Pushing app data folder...');
      final result = await _adb.pushFolder(
        device.serial,
        config.appDataFolder,
        '/sdcard/Android/data/',
      );
      completedSteps++;
      if (result.isSuccess) {
        _log(device.serial, LogSeverity.ok, 'App data pushed successfully.');
      } else {
        _log(device.serial, LogSeverity.error, 'Failed to push app data: ${result.error}');
      }
    }

    // Distribute TPK
    if (tpkFiles.isNotEmpty && !_cancelRequested) {
      FileSystemEntity tpk;
      switch (config.tpkMode) {
        case TpkDistributionMode.sequential:
          tpk = tpkFiles[deviceIndex % tpkFiles.length];
        case TpkDistributionMode.roundRobin:
          tpk = tpkFiles[deviceIndex % tpkFiles.length];
        case TpkDistributionMode.random:
          tpk = tpkFiles[(deviceIndex * 7) % tpkFiles.length]; // deterministic pseudo-random
      }
      updateProgress('Pushing TPK...');
      _log(device.serial, LogSeverity.info, 'Pushing TPK: ${p.basename(tpk.path)}');
      final result = await _adb.pushFolder(device.serial, tpk.path, '/sdcard/');
      completedSteps++;
      if (result.isSuccess) {
        _log(device.serial, LogSeverity.ok, 'TPK pushed successfully.');
      } else {
        _log(device.serial, LogSeverity.error, 'Failed to push TPK: ${result.error}');
      }
    }

    device.status = DeviceStatus.ready;
    device.progress = 1.0;
    device.currentStep = _cancelRequested ? 'Cancelled' : 'Done';
    notifyListeners();
  }

  // ─── De-Provisioning ──────────────────────────────────────────────────────

  Future<void> startDeProvisioning(
    String deviceSourceFolder,
    String outputFolder,
    bool factoryReset,
  ) async {
    final selected = _devices.where((d) => d.isSelected && d.status == DeviceStatus.ready).toList();
    if (selected.isEmpty) {
      _log('system', LogSeverity.warn, 'No ready devices selected.');
      return;
    }
    _status = OperationStatus.deprovisioning;
    _cancelRequested = false;
    notifyListeners();

    _log('system', LogSeverity.info, 'Starting de-provisioning for ${selected.length} device(s)...');

    final semaphore = _Semaphore(_settingsProvider.settings.maxConcurrentDevices.clamp(1, 10));
    final futures = <Future>[];

    for (final device in selected) {
      futures.add(semaphore.run(() async {
        if (_cancelRequested) return;
        await _deprovisionDevice(device, deviceSourceFolder, outputFolder, factoryReset);
      }));
    }

    await Future.wait(futures);

    _status = OperationStatus.idle;
    notifyListeners();
    _log('system', LogSeverity.info, 'De-provisioning complete.');

    try {
      final path = await _reporting.exportProvisioningCsv(
        _settingsProvider.settings.logsDirectory.isNotEmpty
            ? _settingsProvider.settings.logsDirectory
            : 'Logs',
        _logs,
      );
      _log('system', LogSeverity.ok, 'Report saved: $path');
    } catch (e) {
      _log('system', LogSeverity.warn, 'Could not save report: $e');
    }
  }

  Future<void> _deprovisionDevice(
      DeviceInfo device, String deviceSourceFolder, String outputFolder, bool doFactoryReset) async {
    device.status = DeviceStatus.busy;
    device.progress = 0.0;
    notifyListeners();

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final deviceOutput = p.join(outputFolder, '${device.serial}_$timestamp');

    // Pull data
    _log(device.serial, LogSeverity.info, 'Pulling survey data...');
    device.currentStep = 'Pulling data...';
    notifyListeners();

    final pullResult = await _adb.pullFolder(
      device.serial,
      deviceSourceFolder,
      deviceOutput,
    );

    if (pullResult.isSuccess) {
      _log(device.serial, LogSeverity.ok, 'Data pulled to $deviceOutput');
      device.progress = 0.7;
      notifyListeners();
    } else {
      _log(device.serial, LogSeverity.error, 'Data pull failed: ${pullResult.error}');
    }

    // Factory reset
    if (doFactoryReset && !_cancelRequested) {
      device.currentStep = 'Factory reset...';
      notifyListeners();
      _log(device.serial, LogSeverity.warn, 'Initiating factory reset...');
      final resetResult = await _adb.factoryReset(device.serial);
      if (resetResult.isSuccess) {
        _log(device.serial, LogSeverity.ok, 'Factory reset initiated.');
      } else {
        _log(device.serial, LogSeverity.error, 'Factory reset failed: ${resetResult.error}');
      }
    }

    device.status = DeviceStatus.ready;
    device.progress = 1.0;
    device.currentStep = 'Done';
    notifyListeners();
  }

  // ─── Audit ────────────────────────────────────────────────────────────────

  Future<void> auditDevice(String serial) async {
    if (serial.trim().isEmpty) {
      _log('system', LogSeverity.warn, 'Enter a device serial first.');
      return;
    }
    _status = OperationStatus.auditing;
    notifyListeners();
    _log(serial, LogSeverity.info, 'Starting device audit...');

    final results = await Future.wait([
      _adb.getScreenLockStatus(serial),
      _adb.getMdmStatus(serial),
      _adb.getFrpStatus(serial),
      _adb.runDeviceAsync(serial, ['shell', 'dumpsys', 'battery']),
      _adb.runDeviceAsync(serial, ['shell', 'df', '/sdcard']),
    ]);

    final screenLock = results[0] as String;
    final mdm = results[1] as String;
    final frp = results[2] as String;
    final battResult = results[3] as AdbResult;
    final storResult = results[4] as AdbResult;

    // Parse battery
    String battery = 'Unknown';
    final battMatch = RegExp(r'level:\s*(\d+)').firstMatch(battResult.output);
    if (battMatch != null) battery = '${battMatch.group(1)}%';

    // Parse storage
    String storage = 'Unknown';
    for (final line in storResult.output.split('\n')) {
      if (line.contains('/sdcard') || line.contains('fuse')) {
        final cols = line.trim().split(RegExp(r'\s+'));
        if (cols.length >= 4) storage = cols[3];
        break;
      }
    }

    // Build remediation
    final remediation = <String>[];
    if (screenLock.contains('Enabled')) {
      remediation.add('Device is locked — use Clear Lock if PIN is known.');
    }
    if (mdm.contains('MDM active')) {
      remediation.add('MDM detected — unenroll via MDM console before wipe.');
    }
    if (frp.contains('FRP risk')) {
      remediation.add('Google account present — remove before factory reset to avoid FRP lock.');
    }

    _lastAudit = AuditResult(
      deviceSerial: serial,
      screenLock: screenLock,
      frpStatus: frp,
      mdmStatus: mdm,
      batteryLevel: battery,
      storageFree: storage,
      notes: remediation.isEmpty ? 'Device appears clean.' : remediation.join(' '),
      remediationSteps: remediation,
      timestamp: DateTime.now(),
    );

    _log(serial, LogSeverity.ok, 'Audit complete. Lock=$screenLock, FRP=$frp, MDM=$mdm');
    _status = OperationStatus.idle;
    notifyListeners();
  }

  Future<void> clearDeviceLock(String serial, String pin) async {
    if (serial.trim().isEmpty || pin.trim().isEmpty) {
      _log('system', LogSeverity.warn, 'Serial and PIN required.');
      return;
    }
    _log(serial, LogSeverity.info, 'Attempting to clear lock...');
    final result = await _adb.clearLock(serial, pin);
    if (result.isSuccess || result.output.toLowerCase().contains('success')) {
      _log(serial, LogSeverity.ok, 'Lock cleared successfully.');
    } else {
      _log(serial, LogSeverity.error,
          'Clear lock failed: ${result.error.isNotEmpty ? result.error : result.output}');
    }
    notifyListeners();
  }

  Future<void> rebootToRecovery(String serial) async {
    if (serial.trim().isEmpty) {
      _log('system', LogSeverity.warn, 'Enter a device serial first.');
      return;
    }
    _log(serial, LogSeverity.info, 'Rebooting to recovery...');
    final result = await _adb.rebootToRecovery(serial);
    if (result.isSuccess) {
      _log(serial, LogSeverity.ok, 'Reboot to recovery initiated.');
    } else {
      _log(serial, LogSeverity.error, 'Reboot failed: ${result.error}');
    }
    notifyListeners();
  }

  void requestCancel() {
    _cancelRequested = true;
    _log('system', LogSeverity.warn, 'Cancellation requested...');
    notifyListeners();
  }

  Future<String> exportCsv() async {
    try {
      final path = await _reporting.exportProvisioningCsv(
        _settingsProvider.settings.logsDirectory.isNotEmpty
            ? _settingsProvider.settings.logsDirectory
            : 'Logs',
        _logs,
      );
      _log('system', LogSeverity.ok, 'CSV exported: $path');
      notifyListeners();
      return path;
    } catch (e) {
      _log('system', LogSeverity.error, 'Export failed: $e');
      notifyListeners();
      return '';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _settingsProvider.removeListener(_initAdb);
    // Best-effort cleanup: don't leave adb.exe running.
    unawaited(_adb.shutdown());
    super.dispose();
  }
}

// Simple semaphore for concurrency limiting
class _Semaphore {
  final int maxCount;
  int _current = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<T> run<T>(Future<T> Function() fn) async {
    await _acquire();
    try {
      return await fn();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_current < maxCount) {
      _current++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
    _current++;
  }

  void _release() {
    _current--;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next.complete();
    }
  }
}
