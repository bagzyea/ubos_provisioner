using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UbosProvisioner.Models;
using UbosProvisioner.Services;

namespace UbosProvisioner.ViewModels;

public partial class DeviceAuditViewModel : ObservableObject
{
    private readonly IDeviceAuditService _auditService;
    private CancellationTokenSource? _auditCts;

    [ObservableProperty]
    private ObservableCollection<DeviceAuditReport> auditReports = new();

    [ObservableProperty]
    private string statusMessage = "Ready";

    [ObservableProperty]
    private bool isAuditing = false;

    [ObservableProperty]
    private string selectedDeviceSerial = string.Empty;

    [ObservableProperty]
    private string pinForUnlock = string.Empty;

    [ObservableProperty]
    private string auditDetails = string.Empty;

    public DeviceAuditViewModel(IDeviceAuditService auditService)
    {
        _auditService = auditService;
    }

    [RelayCommand]
    private void AuditAllDevices()
    {
        _ = AuditAllDevicesAsync();
    }

    private async Task AuditAllDevicesAsync()
    {
        IsAuditing = true;
        AuditReports.Clear();
        StatusMessage = "Auditing devices...";
        _auditCts = new CancellationTokenSource();

        try
        {
            var progress = new Progress<ProvisioningUpdate>(update =>
            {
                App.Current?.Dispatcher.Invoke(() =>
                {
                    StatusMessage = $"[{update.DeviceSerial}] {update.Message}";
                });
            });

            // This would need devices list from parent ViewModel
            // For now, create a placeholder
            StatusMessage = "Select devices to audit from the main window";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsAuditing = false;
            _auditCts?.Dispose();
        }
    }

    [RelayCommand]
    private void AuditSingleDevice()
    {
        _ = AuditSingleDeviceAsync();
    }

    private async Task AuditSingleDeviceAsync()
    {
        if (string.IsNullOrEmpty(SelectedDeviceSerial))
        {
            StatusMessage = "Please select a device serial number";
            return;
        }

        IsAuditing = true;
        StatusMessage = "Auditing device...";
        _auditCts = new CancellationTokenSource();

        try
        {
            var report = await _auditService.AuditDeviceAsync(SelectedDeviceSerial, _auditCts.Token);
            AuditReports.Clear();
            AuditReports.Add(report);
            AuditDetails = report.RemediationInstructions;
            StatusMessage = "Audit complete";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsAuditing = false;
            _auditCts?.Dispose();
        }
    }

    [RelayCommand]
    private void ClearLock()
    {
        _ = ClearLockAsync();
    }

    private async Task ClearLockAsync()
    {
        if (string.IsNullOrEmpty(SelectedDeviceSerial))
        {
            StatusMessage = "Please select a device serial number";
            return;
        }

        if (string.IsNullOrEmpty(PinForUnlock))
        {
            StatusMessage = "Please enter the PIN";
            return;
        }

        StatusMessage = "Attempting to clear lock...";
        _auditCts = new CancellationTokenSource();

        try
        {
            var result = await _auditService.ClearLockWithPinAsync(SelectedDeviceSerial, PinForUnlock, _auditCts.Token);
            if (result.IsSuccess)
            {
                StatusMessage = "Lock cleared successfully! Device may require restart.";
                PinForUnlock = string.Empty;
            }
            else
            {
                StatusMessage = $"Lock clear failed: {result.Error}";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            _auditCts?.Dispose();
        }
    }

    [RelayCommand]
    private void RebootToRecovery()
    {
        _ = RebootToRecoveryAsync();
    }

    private async Task RebootToRecoveryAsync()
    {
        if (string.IsNullOrEmpty(SelectedDeviceSerial))
        {
            StatusMessage = "Please select a device serial number";
            return;
        }

        StatusMessage = "Rebooting to recovery mode...";
        _auditCts = new CancellationTokenSource();

        try
        {
            var result = await _auditService.RebootToRecoveryAsync(SelectedDeviceSerial, _auditCts.Token);
            if (result.IsSuccess)
            {
                StatusMessage = "Device rebooting to recovery. Complete manual wipe on device.";
            }
            else
            {
                StatusMessage = $"Reboot failed: {result.Error}";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            _auditCts?.Dispose();
        }
    }

    [RelayCommand]
    private void CancelAudit()
    {
        _auditCts?.Cancel();
        IsAuditing = false;
        StatusMessage = "Audit cancelled";
    }
}
