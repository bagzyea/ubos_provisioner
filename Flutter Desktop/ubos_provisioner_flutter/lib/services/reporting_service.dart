import 'dart:io';
import '../models/log_entry.dart';

class ReportingService {
  static String get defaultLogsDir {
    final userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    return '$userProfile\\Documents\\UBOS Provisioner\\Logs';
  }

  Future<String> exportProvisioningCsv(String logsDir, List<LogEntry> logs) async {
    final dir = Directory(logsDir.isNotEmpty ? logsDir : defaultLogsDir);
    await dir.create(recursive: true);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = File('${dir.path}\\provisioning_$timestamp.csv');
    final buffer = StringBuffer();
    buffer.writeln('"Timestamp","Device","Severity","Message"');
    for (final entry in logs) {
      buffer.writeln(entry.toCsvRow());
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportAuditCsv(String logsDir, Map<String, dynamic> auditData) async {
    final dir = Directory(logsDir.isNotEmpty ? logsDir : defaultLogsDir);
    await dir.create(recursive: true);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = File('${dir.path}\\audit_$timestamp.csv');
    final buffer = StringBuffer();
    buffer.writeln('"Timestamp","Device","ScreenLock","FRP","MDM","Battery","Storage","Notes"');
    buffer.writeln('"${auditData['timestamp']}","${auditData['serial']}","${auditData['screenLock']}","${auditData['frp']}","${auditData['mdm']}","${auditData['battery']}","${auditData['storage']}","${auditData['notes']}"');
    await file.writeAsString(buffer.toString());
    return file.path;
  }
}
