namespace UbosProvisioner.Models;

public class AppSettings
{
    public int MaxConcurrentDevices { get; set; } = 3;
    public int DevicePollIntervalMs { get; set; } = 5000;
    public string LogsDirectory { get; set; } = "./Logs";
    public string PlatformToolsPath { get; set; } = "./platform-tools";
    public string DefaultTheme { get; set; } = "Light";
}

public class AppConfig
{
    public AppSettings AppSettings { get; set; } = new();
}
