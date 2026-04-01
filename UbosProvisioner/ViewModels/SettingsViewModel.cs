using System;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UbosProvisioner.Models;

namespace UbosProvisioner.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly AppSettings _appSettings;

    [ObservableProperty]
    private int maxConcurrentDevices;

    [ObservableProperty]
    private int devicePollIntervalMs;

    [ObservableProperty]
    private string logsDirectory = string.Empty;

    [ObservableProperty]
    private string platformToolsPath = string.Empty;

    [ObservableProperty]
    private string statusMessage = "Settings loaded";

    public SettingsViewModel(AppSettings appSettings)
    {
        _appSettings = appSettings;
        LoadSettings();
    }

    private void LoadSettings()
    {
        MaxConcurrentDevices = _appSettings.MaxConcurrentDevices;
        DevicePollIntervalMs = _appSettings.DevicePollIntervalMs;
        LogsDirectory = _appSettings.LogsDirectory;
        PlatformToolsPath = _appSettings.PlatformToolsPath;
    }

    [RelayCommand]
    private void SaveSettings()
    {
        try
        {
            _appSettings.MaxConcurrentDevices = MaxConcurrentDevices;
            _appSettings.DevicePollIntervalMs = DevicePollIntervalMs;
            _appSettings.LogsDirectory = LogsDirectory;
            _appSettings.PlatformToolsPath = PlatformToolsPath;

            StatusMessage = "Settings saved successfully";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error saving settings: {ex.Message}";
        }
    }

    [RelayCommand]
    private void ResetToDefaults()
    {
        MaxConcurrentDevices = 3;
        DevicePollIntervalMs = 5000;
        LogsDirectory = "./Logs";
        PlatformToolsPath = "./platform-tools";
        StatusMessage = "Reset to default settings";
    }
}
