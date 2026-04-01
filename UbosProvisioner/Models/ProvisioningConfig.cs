using System.Collections.Generic;

namespace UbosProvisioner.Models;

public enum TpkDistributionMode
{
    Sequential,
    RoundRobin,
    Random
}

public class ProvisioningConfig
{
    public List<string> ApkPaths { get; set; } = new();
    public string AppDataPath { get; set; } = string.Empty;
    public string TpkFolderPath { get; set; } = string.Empty;
    public TpkDistributionMode TpkMode { get; set; } = TpkDistributionMode.RoundRobin;
    public string EnumeratorUserName { get; set; } = "Enumerator";
    public int ScreenTimeoutSeconds { get; set; } = 300;
    public bool CaptureScreenshots { get; set; } = true;
    public string ScreenshotOutputPath { get; set; } = "./QC_Screenshots";
    public string DevicePin { get; set; } = string.Empty;
    public ApnConfig? Apn { get; set; }
}

public class ApnConfig
{
    public string Name { get; set; } = string.Empty;
    public string Apn { get; set; } = string.Empty;
    public string Mcc { get; set; } = string.Empty;
    public string Mnc { get; set; } = string.Empty;
    public string Type { get; set; } = "default";
}
