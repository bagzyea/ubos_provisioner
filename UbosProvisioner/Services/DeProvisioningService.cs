using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class DeProvisioningService : IDeProvisioningService
{
    private readonly IAdbService _adbService;
    private readonly AppSettings _config;

    public DeProvisioningService(IAdbService adbService, AppSettings config)
    {
        _adbService = adbService;
        _config = config;
    }

    /// <summary>
    /// Execute full de-provisioning on devices (extract data + factory reset).
    /// </summary>
    public async Task DeProvisionDevicesAsync(
        List<DeviceInfo> devices,
        string outputDataPath,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default)
    {
        if (devices.Count == 0)
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "De-Provision",
                Status = ProvisioningStatus.Failed,
                Message = "No devices selected"
            });
            return;
        }

        // Validate output path
        if (string.IsNullOrEmpty(outputDataPath))
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "De-Provision",
                Status = ProvisioningStatus.Failed,
                Message = "Output data path is required"
            });
            return;
        }

        // Use semaphore to limit concurrent operations
        var semaphore = new SemaphoreSlim(_config.MaxConcurrentDevices);
        var tasks = new List<Task>();

        foreach (var device in devices)
        {
            await semaphore.WaitAsync(ct);
            tasks.Add(DeProvisionSingleDeviceAsync(device, outputDataPath, progress, ct)
                .ContinueWith(_ => semaphore.Release()));
        }

        await Task.WhenAll(tasks);
    }

    /// <summary>
    /// De-provision a single device: extract data, then factory reset.
    /// </summary>
    private async Task DeProvisionSingleDeviceAsync(
        DeviceInfo device,
        string outputDataPath,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct)
    {
        try
        {
            // 1. Pull sensitive data
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Extract Data",
                Status = ProvisioningStatus.InProgress,
                Message = "Pulling sensitive data..."
            });

            var pullResult = await PullDataAsync(device.Serial, outputDataPath, progress, ct);
            if (!pullResult.IsSuccess)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Extract Data",
                    Status = ProvisioningStatus.Failed,
                    Message = pullResult.Error
                });
                return;
            }

            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Extract Data",
                Status = ProvisioningStatus.Success,
                Message = "Data extracted successfully"
            });

            // 2. Issue FRP warning before factory reset
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "FRP Warning",
                Status = ProvisioningStatus.InProgress,
                Message = "If a Google/MDM account is signed in, FRP will activate after reset. Device will require account credentials to complete setup."
            });

            // 3. Factory reset
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Factory Reset",
                Status = ProvisioningStatus.InProgress,
                Message = "Initiating factory reset..."
            });

            var resetResult = await FactoryResetAsync(device.Serial, progress, ct);
            if (!resetResult.IsSuccess)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Factory Reset",
                    Status = ProvisioningStatus.Failed,
                    Message = resetResult.Error
                });
            }
            else
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Factory Reset",
                    Status = ProvisioningStatus.Success,
                    Message = "Factory reset initiated. Device will reboot."
                });
            }

            // Final status
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "De-Provision Complete",
                Status = ProvisioningStatus.Success,
                Message = "Device de-provisioned successfully"
            });
        }
        catch (OperationCanceledException)
        {
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "De-Provision",
                Status = ProvisioningStatus.Failed,
                Message = "Operation cancelled"
            });
        }
        catch (Exception ex)
        {
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "De-Provision",
                Status = ProvisioningStatus.Failed,
                Message = $"Error: {ex.Message}"
            });
        }
    }

    /// <summary>
    /// Pull sensitive census/survey data from /sdcard/Android/data/
    /// </summary>
    public async Task<AdbResult> PullDataAsync(string serial, string outputPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        Directory.CreateDirectory(outputPath);
        string deviceDataFolder = Path.Combine(outputPath, $"{serial}_{DateTime.Now:yyyyMMdd_HHmmss}");
        Directory.CreateDirectory(deviceDataFolder);

        // Pull entire /sdcard/Android/data/ folder
        return await _adbService.RunAsync($"-s {serial} pull", $"/sdcard/Android/data/ \"{deviceDataFolder}\"", ct);
    }

    /// <summary>
    /// Trigger factory reset via recovery (wipe_data).
    /// </summary>
    public async Task<AdbResult> FactoryResetAsync(string serial, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        // Option 1: Using recovery command (requires recovery mode)
        // return await _adbService.RunAsync("shell", $"-s {serial} recovery --wipe_data", ct);

        // Option 2: Using settings command (Android 5+)
        return await _adbService.RunAsync($"-s {serial} shell", "am start -a android.intent.action.FACTORY_RESET", ct);
    }
}
