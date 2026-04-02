enum DeviceStatus { ready, unauthorized, offline, busy }

class DeviceInfo {
  final String serial;
  String model;
  String androidVersion;
  String batteryLevel;
  String storageFree;
  DeviceStatus status;
  bool isSelected;
  double progress;
  String currentStep;

  DeviceInfo({
    required this.serial,
    this.model = 'Unknown',
    this.androidVersion = '',
    this.batteryLevel = '',
    this.storageFree = '',
    this.status = DeviceStatus.ready,
    this.isSelected = false,
    this.progress = 0.0,
    this.currentStep = '',
  });

  String get statusLabel => switch (status) {
    DeviceStatus.ready => 'Ready',
    DeviceStatus.unauthorized => 'Unauthorized',
    DeviceStatus.offline => 'Offline',
    DeviceStatus.busy => 'Busy',
  };
}
