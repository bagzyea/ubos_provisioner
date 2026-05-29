enum TpkDistributionMode { sequential, roundRobin, random }

class ProvisioningConfig {
  List<String> apkPaths;
  String appDataFolder;
  String tpkFolder;
  TpkDistributionMode tpkMode;
  int maxParallel;
  String devicePin;

  ProvisioningConfig({
    List<String>? apkPaths,
    this.appDataFolder = '',
    this.tpkFolder = '',
    this.tpkMode = TpkDistributionMode.roundRobin,
    this.maxParallel = 3,
    this.devicePin = '',
  }) : apkPaths = apkPaths ?? [];
}
