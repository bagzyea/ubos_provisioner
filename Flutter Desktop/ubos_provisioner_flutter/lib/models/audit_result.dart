class AuditResult {
  final String deviceSerial;
  final String screenLock;
  final String frpStatus;
  final String mdmStatus;
  final String batteryLevel;
  final String storageFree;
  final String notes;
  final List<String> remediationSteps;
  final DateTime timestamp;

  const AuditResult({
    required this.deviceSerial,
    required this.screenLock,
    required this.frpStatus,
    required this.mdmStatus,
    required this.batteryLevel,
    required this.storageFree,
    required this.notes,
    required this.remediationSteps,
    required this.timestamp,
  });
}
