enum LogSeverity { info, ok, warn, error }

class LogEntry {
  final DateTime timestamp;
  final String deviceSerial;
  final LogSeverity severity;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.deviceSerial,
    required this.severity,
    required this.message,
  });

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

  String get severityLabel => switch (severity) {
    LogSeverity.info => 'INFO',
    LogSeverity.ok => 'OK',
    LogSeverity.warn => 'WARN',
    LogSeverity.error => 'ERR',
  };

  String toCsvRow() =>
      '"${timestamp.toIso8601String()}","$deviceSerial","$severityLabel","${message.replaceAll('"', '""')}"';
}
