import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device_info.dart';

class AdbResult {
  final int exitCode;
  final String output;
  final String error;
  bool get isSuccess => exitCode == 0;

  const AdbResult({required this.exitCode, required this.output, required this.error});
}

class AdbService {
  String adbPath;
  static const _timeout = Duration(seconds: 60);
  final Set<Process> _activeProcesses = {};

  AdbService(this.adbPath);

  // Resolve adb path: use provided path, fallback to platform-tools next to exe, then PATH
  static String resolveAdbPath(String configuredPath) {
    if (configuredPath.isNotEmpty) {
      // Could be directory or full path to adb.exe
      final f = File(configuredPath);
      if (f.existsSync()) return configuredPath;
      final inDir = File('$configuredPath\\adb.exe');
      if (inDir.existsSync()) return inDir.path;
    }
    // Try beside the executable
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final beside = File('$exeDir\\platform-tools\\adb.exe');
      if (beside.existsSync()) return beside.path;
      // Also try same folder
      final same = File('$exeDir\\adb.exe');
      if (same.existsSync()) return same.path;
    } catch (_) {}
    return 'adb'; // fall back to PATH
  }

  Future<AdbResult> runAsync(List<String> args, {Duration? timeout}) async {
    try {
      final result = await Process.run(
        adbPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout ?? _timeout);
      return AdbResult(
        exitCode: result.exitCode,
        output: (result.stdout as String).trim(),
        error: (result.stderr as String).trim(),
      );
    } on TimeoutException {
      return const AdbResult(exitCode: -1, output: '', error: 'Command timed out');
    } catch (e) {
      return AdbResult(exitCode: -1, output: '', error: e.toString());
    }
  }

  Future<AdbResult> runDeviceAsync(String serial, List<String> args, {Duration? timeout}) {
    return runAsync(['-s', serial, ...args], timeout: timeout);
  }

  // Stream process output line by line for long-running commands
  Stream<String> streamDeviceAsync(String serial, List<String> args) async* {
    Process process;
    try {
      process = await Process.start(adbPath, ['-s', serial, ...args]);
      _activeProcesses.add(process);
    } catch (e) {
      yield 'ERROR: $e';
      return;
    }
    try {
      await for (final line in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        yield line;
      }
      await process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((_) {});
    } finally {
      _activeProcesses.remove(process);
    }
  }

  Future<List<DeviceInfo>> getConnectedDevicesAsync() async {
    final result = await runAsync(['devices']);
    if (!result.isSuccess && result.output.isEmpty) return [];

    final lines = result.output.split('\n');
    final devices = <DeviceInfo>[];
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('\t');
      if (parts.length < 2) continue;
      final serial = parts[0].trim();
      final state = parts[1].trim();
      if (serial.isEmpty) continue;

      final status = switch (state) {
        'device' => DeviceStatus.ready,
        'unauthorized' => DeviceStatus.unauthorized,
        _ => DeviceStatus.offline,
      };

      devices.add(DeviceInfo(serial: serial, status: status));
    }
    return devices;
  }

  Future<bool> waitForDeviceReady(
    String serial, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      final state = await runDeviceAsync(serial, ['get-state'], timeout: const Duration(seconds: 3));
      if (state.isSuccess && state.output.trim() == 'device') return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> loadDeviceProperties(DeviceInfo device) async {
    if (device.status != DeviceStatus.ready) return;
    final ready = await waitForDeviceReady(device.serial);
    if (!ready) return;

    final futures = await Future.wait([
      runDeviceAsync(device.serial, ['shell', 'getprop', 'ro.product.model']),
      runDeviceAsync(device.serial, ['shell', 'getprop', 'ro.build.version.release']),
      runDeviceAsync(device.serial, ['shell', 'dumpsys', 'battery']),
      runDeviceAsync(device.serial, ['shell', 'df', '/sdcard']),
      runDeviceAsync(device.serial, ['shell', 'dumpsys', 'account']),
    ]);

    device.model = futures[0].output.isNotEmpty ? futures[0].output : 'Unknown';
    device.androidVersion = futures[1].output.isNotEmpty ? futures[1].output : '';

    // Parse battery level
    final batteryOutput = futures[2].output;
    final batteryMatch = RegExp(r'level:\s*(\d+)').firstMatch(batteryOutput);
    device.batteryLevel = batteryMatch != null ? '${batteryMatch.group(1)}%' : '';

    // Parse storage free
    final storageOutput = futures[3].output;
    final storageLines = storageOutput.split('\n');
    for (final line in storageLines) {
      if (line.contains('/sdcard') || line.contains('fuse')) {
        final cols = line.trim().split(RegExp(r'\s+'));
        if (cols.length >= 4) {
          device.storageFree = cols[3]; // 4th column is "Available"
        }
        break;
      }
    }

    // Detect Google account presence (FRP risk indicator)
    final accountsOutput = futures[4].output.toLowerCase();
    if (accountsOutput.isEmpty) {
      device.googleAccountStatus = 'Unknown';
    } else if (accountsOutput.contains('com.google')) {
      device.googleAccountStatus = 'Present';
    } else {
      device.googleAccountStatus = 'Not present';
    }
  }

  Future<AdbResult> installApk(String serial, String apkPath,
      {void Function(String)? onProgress}) async {
    onProgress?.call('Installing ${File(apkPath).uri.pathSegments.last}...');
    return runDeviceAsync(serial, ['install', '-r', apkPath],
        timeout: const Duration(minutes: 5));
  }

  Future<AdbResult> pushFolder(String serial, String localPath, String remotePath,
      {void Function(String)? onProgress}) async {
    onProgress?.call('Pushing ${File(localPath).uri.pathSegments.last}...');
    return runDeviceAsync(serial, ['push', localPath, remotePath],
        timeout: const Duration(minutes: 10));
  }

  Future<AdbResult> pullFolder(String serial, String remotePath, String localPath,
      {void Function(String)? onProgress}) async {
    onProgress?.call('Pulling data from $remotePath...');
    await Directory(localPath).create(recursive: true);
    return runDeviceAsync(serial, ['pull', remotePath, localPath],
        timeout: const Duration(minutes: 15));
  }

  Future<AdbResult> factoryReset(String serial) {
    return runDeviceAsync(serial, ['shell', 'am', 'broadcast', '-a', 'android.intent.action.MASTER_CLEAR'],
        timeout: const Duration(minutes: 2));
  }

  Future<AdbResult> rebootToRecovery(String serial) {
    return runDeviceAsync(serial, ['reboot', 'recovery'],
        timeout: const Duration(seconds: 30));
  }

  Future<String> getScreenLockStatus(String serial) async {
    final result = await runDeviceAsync(serial, ['shell', 'locksettings', 'get-disabled']);
    if (!result.isSuccess) return 'Unknown';
    final output = result.output.toLowerCase();
    if (output.contains('true')) return 'Disabled (no lock)';
    if (output.contains('false')) return 'Enabled (locked)';
    return 'Unknown';
  }

  Future<String> getMdmStatus(String serial) async {
    final result = await runDeviceAsync(serial, ['shell', 'dumpsys', 'device_policy']);
    if (!result.isSuccess || result.output.isEmpty) return 'None detected';
    if (result.output.toLowerCase().contains('device owner')) return 'Device Owner (MDM active)';
    if (result.output.toLowerCase().contains('profile owner')) return 'Profile Owner (MDM active)';
    return 'None detected';
  }

  Future<String> getFrpStatus(String serial) async {
    final result = await runDeviceAsync(serial, ['shell', 'dumpsys', 'account']);
    if (!result.isSuccess) return 'Unknown';
    final hasGoogle = result.output.toLowerCase().contains('com.google');
    return hasGoogle ? 'Google account present (FRP risk)' : 'No Google account detected';
  }

  Future<AdbResult> clearLock(String serial, String pin) {
    return runDeviceAsync(serial, ['shell', 'locksettings', 'clear', '--old', pin]);
  }

  /// Best-effort cleanup so the app doesn't leave an `adb.exe` server running.
  ///
  /// - Kills any child processes started via `Process.start` in this service.
  /// - Runs `adb kill-server` to stop the ADB daemon.
  Future<void> shutdown() async {
    for (final p in _activeProcesses.toList()) {
      try {
        p.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _activeProcesses.clear();
    try {
      await runAsync(['kill-server'], timeout: const Duration(seconds: 10));
    } catch (_) {}
  }
}
