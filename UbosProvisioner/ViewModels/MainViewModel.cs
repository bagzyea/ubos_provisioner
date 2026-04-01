using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UbosProvisioner.Models;
using UbosProvisioner.Services;

namespace UbosProvisioner.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IAdbService _adbService;
    private readonly IProvisioningService _provisioningService;
    private readonly IDeProvisioningService _deProvisioningService;
    private readonly ReportingService _reportingService;
    private CancellationTokenSource? _provisioningCts;
    private CancellationTokenSource? _deProvisioningCts;

    [ObservableProperty]
    private ObservableCollection<DeviceInfo> devices = new();

    [ObservableProperty]
    private ObservableCollection<ProvisioningUpdate> provisioningLog = new();

    [ObservableProperty]
    private string statusMessage = "Ready";

    [ObservableProperty]
    private bool isPolling = false;

    [ObservableProperty]
    private bool isProvisioning = false;

    [ObservableProperty]
    private ObservableCollection<string> apkPaths = new();

    [ObservableProperty]
    private string appDataPath = string.Empty;

    [ObservableProperty]
    private string tpkFolderPath = string.Empty;

    [ObservableProperty]
    private TpkDistributionMode selectedTpkMode = TpkDistributionMode.RoundRobin;

    [ObservableProperty]
    private string devicePin = string.Empty;

    [ObservableProperty]
    private string apnName = string.Empty;

    [ObservableProperty]
    private string apnValue = string.Empty;

    [ObservableProperty]
    private string apnMcc = string.Empty;

    [ObservableProperty]
    private string apnMnc = string.Empty;

    [ObservableProperty]
    private string apnType = "default";

    [ObservableProperty]
    private bool isDeProvisioning = false;

    [ObservableProperty]
    private string extractDataOutputPath = "./Extracted_Data";

    [ObservableProperty]
    private SettingsViewModel? settings;

    [ObservableProperty]
    private string settingsStatus = "Settings ready";

    [ObservableProperty]
    private DeviceAuditViewModel? deviceAudit;

    public MainViewModel(IAdbService adbService, IProvisioningService provisioningService, IDeProvisioningService deProvisioningService, AppSettings appSettings, IDeviceAuditService auditService, ReportingService reportingService)
    {
        _adbService = adbService;
        _provisioningService = provisioningService;
        _deProvisioningService = deProvisioningService;
        _reportingService = reportingService;
        Settings = new SettingsViewModel(appSettings);
        DeviceAudit = new DeviceAuditViewModel(auditService);
    }

    [RelayCommand]
    private void RefreshDevices()
    {
        _ = RefreshDevicesAsync();
    }

    private async Task RefreshDevicesAsync()
    {
        try
        {
            StatusMessage = "Fetching devices...";
            var deviceList = await _adbService.GetConnectedDevicesAsync();

            Devices.Clear();
            foreach (var device in deviceList)
            {
                Devices.Add(device);
            }

            if (Devices.Count == 0)
            {
                StatusMessage = "No devices connected. Ensure platform-tools/adb.exe is in place and devices are connected via USB.";
            }
            else
            {
                StatusMessage = $"Found {Devices.Count} device(s)";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void StartPolling()
    {
        try
        {
            StatusMessage = "Device polling started...";
            IsPolling = true;

            _adbService.StartDevicePolling(devices =>
            {
                // Update UI on main thread
                App.Current?.Dispatcher.Invoke(() =>
                {
                    var toRemove = Devices.Where(d => !devices.Any(newD => newD.Serial == d.Serial)).ToList();
                    foreach (var rm in toRemove)
                    {
                        Devices.Remove(rm);
                    }

                    foreach (var newDev in devices)
                    {
                        var existing = Devices.FirstOrDefault(d => d.Serial == newDev.Serial);
                        if (existing != null)
                        {
                            existing.ConnectionState = newDev.ConnectionState;
                            existing.BatteryLevel = newDev.BatteryLevel;
                            existing.StorageFree = newDev.StorageFree;
                        }
                        else
                        {
                            Devices.Add(newDev);
                        }
                    }
                    StatusMessage = $"Found {Devices.Count} device(s)";
                });
            }, 5000);
        }
        catch (Exception ex)
        {
            StatusMessage = $"Polling error: {ex.Message}";
            IsPolling = false;
        }
    }

    [RelayCommand]
    private void StopPolling()
    {
        try
        {
            _adbService.StopDevicePolling();
            IsPolling = false;
            StatusMessage = "Device polling stopped";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Stop polling error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void SelectAllDevices()
    {
        foreach (var device in Devices)
        {
            device.IsSelected = true;
        }
        StatusMessage = $"Selected all {Devices.Count} device(s)";
    }

    [RelayCommand]
    private void DeselectAllDevices()
    {
        foreach (var device in Devices)
        {
            device.IsSelected = false;
        }
        StatusMessage = "Deselected all devices";
    }

    [RelayCommand]
    private void StartProvisioning()
    {
        _ = StartProvisioningAsync();
    }

    private async Task StartProvisioningAsync()
    {
        // Validate selection
        var selectedDevices = Devices.Where(d => d.IsSelected).ToList();
        if (selectedDevices.Count == 0)
        {
            StatusMessage = "No devices selected";
            return;
        }

        // Validate config
        if (ApkPaths.Count == 0)
        {
            StatusMessage = "At least one APK must be selected";
            return;
        }

        IsProvisioning = true;
        ProvisioningLog.Clear();
        StatusMessage = "Provisioning started...";
        _provisioningCts = new CancellationTokenSource();

        try
        {
            var config = new ProvisioningConfig
            {
                ApkPaths = new List<string>(ApkPaths),
                AppDataPath = AppDataPath,
                TpkFolderPath = TpkFolderPath,
                TpkMode = SelectedTpkMode,
                CaptureScreenshots = true,
                DevicePin = DevicePin,
                Apn = !string.IsNullOrEmpty(ApnValue) ? new ApnConfig
                {
                    Name = ApnName,
                    Apn = ApnValue,
                    Mcc = ApnMcc,
                    Mnc = ApnMnc,
                    Type = ApnType
                } : null
            };

            var progress = new Progress<ProvisioningUpdate>(update =>
            {
                App.Current?.Dispatcher.Invoke(() =>
                {
                    ProvisioningLog.Add(update);
                    StatusMessage = $"[{update.DeviceSerial}] {update.Operation}: {update.Message}";
                });
            });

            await _provisioningService.ProvisionDevicesAsync(selectedDevices, config, progress, _provisioningCts.Token);

            StatusMessage = "Provisioning completed";
        }
        catch (OperationCanceledException)
        {
            StatusMessage = "Provisioning cancelled";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Provisioning error: {ex.Message}";
        }
        finally
        {
            IsProvisioning = false;
            _provisioningCts?.Dispose();

            // Save logs to file
            if (ProvisioningLog.Count > 0)
            {
                try
                {
                    var logs = ProvisioningLog.ToList();
                    var savedPath = await _reportingService.GenerateProvisioningSummaryAsync(logs);
                    StatusMessage = $"Provisioning completed. Logs saved to {Path.GetFileName(savedPath)}";
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Provisioning completed, but log save failed: {ex.Message}";
                }
            }
        }
    }

    [RelayCommand]
    private void CancelProvisioning()
    {
        _provisioningCts?.Cancel();
        IsProvisioning = false;
        StatusMessage = "Provisioning cancelled";
    }

    [RelayCommand]
    private void SelectApk()
    {
        var dialog = new System.Windows.Forms.OpenFileDialog
        {
            Filter = "Android Packages (*.apk)|*.apk|All Files (*.*)|*.*",
            Title = "Select APK to Install",
            Multiselect = true
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            ApkPaths.Clear();
            foreach (var apkFile in dialog.FileNames)
            {
                ApkPaths.Add(apkFile);
            }
            StatusMessage = $"{ApkPaths.Count} APK(s) selected";
        }
    }

    [RelayCommand]
    private void SelectAppData()
    {
        var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = "Select App Data Folder"
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            AppDataPath = dialog.SelectedPath;
            StatusMessage = $"App data folder selected";
        }
    }

    [RelayCommand]
    private void SelectTpkFolder()
    {
        var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = "Select TPK Folder"
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            TpkFolderPath = dialog.SelectedPath;
            StatusMessage = $"TPK folder selected";
        }
    }

    [RelayCommand]
    private void StartDeProvisioning()
    {
        _ = StartDeProvisioningAsync();
    }

    private async Task StartDeProvisioningAsync()
    {
        // Validate selection
        var selectedDevices = Devices.Where(d => d.IsSelected).ToList();
        if (selectedDevices.Count == 0)
        {
            StatusMessage = "No devices selected for de-provisioning";
            return;
        }

        IsDeProvisioning = true;
        ProvisioningLog.Clear();
        StatusMessage = "De-provisioning started...";
        _deProvisioningCts = new CancellationTokenSource();

        try
        {
            var progress = new Progress<ProvisioningUpdate>(update =>
            {
                App.Current?.Dispatcher.Invoke(() =>
                {
                    ProvisioningLog.Add(update);
                    StatusMessage = $"[{update.DeviceSerial}] {update.Operation}: {update.Message}";
                });
            });

            await _deProvisioningService.DeProvisionDevicesAsync(selectedDevices, ExtractDataOutputPath, progress, _deProvisioningCts.Token);

            StatusMessage = "De-provisioning completed";
        }
        catch (OperationCanceledException)
        {
            StatusMessage = "De-provisioning cancelled";
        }
        catch (Exception ex)
        {
            StatusMessage = $"De-provisioning error: {ex.Message}";
        }
        finally
        {
            IsDeProvisioning = false;
            _deProvisioningCts?.Dispose();

            // Save logs to file
            if (ProvisioningLog.Count > 0)
            {
                try
                {
                    var logs = ProvisioningLog.ToList();
                    var savedPath = await _reportingService.GenerateProvisioningSummaryAsync(logs);
                    StatusMessage = $"De-provisioning completed. Logs saved to {Path.GetFileName(savedPath)}";
                }
                catch (Exception ex)
                {
                    StatusMessage = $"De-provisioning completed, but log save failed: {ex.Message}";
                }
            }
        }
    }

    [RelayCommand]
    private void CancelDeProvisioning()
    {
        _deProvisioningCts?.Cancel();
        IsDeProvisioning = false;
        StatusMessage = "De-provisioning cancelled";
    }

    [RelayCommand]
    private void SelectExtractDataOutput()
    {
        var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = "Select Output Folder for Extracted Data"
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            ExtractDataOutputPath = dialog.SelectedPath;
            StatusMessage = $"Extract data folder selected";
        }
    }

    [RelayCommand]
    private void ExportOperationLog()
    {
        try
        {
            if (ProvisioningLog.Count == 0)
            {
                StatusMessage = "No operations to export";
                return;
            }

            var dialog = new System.Windows.Forms.SaveFileDialog
            {
                Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*",
                Title = "Export Operation Log",
                DefaultExt = "csv",
                FileName = $"provisioning_log_{DateTime.Now:yyyyMMdd_HHmmss}.csv"
            };

            if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                var csv = new StringBuilder();
                csv.AppendLine("Timestamp,Device Serial,Operation,Message");
                foreach (var update in ProvisioningLog)
                {
                    csv.AppendLine($"\"{update.Timestamp:yyyy-MM-dd HH:mm:ss}\",\"{update.DeviceSerial}\",\"{update.Operation}\",\"{update.Message}\"");
                }
                File.WriteAllText(dialog.FileName, csv.ToString());
                StatusMessage = $"Log exported to {dialog.FileName}";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Export error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void OpenLogsFolder()
    {
        try
        {
            string logsPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Logs");
            if (!Directory.Exists(logsPath))
            {
                Directory.CreateDirectory(logsPath);
            }
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "explorer.exe",
                Arguments = logsPath,
                UseShellExecute = true
            });
            StatusMessage = "Logs folder opened";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Open folder error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void ClearProvisioningLog()
    {
        ProvisioningLog.Clear();
        StatusMessage = "Provisioning log cleared";
    }
}
