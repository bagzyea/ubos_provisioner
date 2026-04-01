using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class ProvisioningService : IProvisioningService
{
    private readonly IAdbService _adbService;
    private readonly AppSettings _config;
    private int _tpkDistributionIndex = 0;
    private string[]? _cachedTpkFiles;

    public ProvisioningService(IAdbService adbService, AppSettings config)
    {
        _adbService = adbService;
        _config = config;
    }

    /// <summary>
    /// Execute full provisioning on devices sequentially with concurrency control.
    /// </summary>
    public async Task ProvisionDevicesAsync(
        List<DeviceInfo> devices,
        ProvisioningConfig config,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default)
    {
        if (devices.Count == 0)
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "Provision",
                Status = ProvisioningStatus.Failed,
                Message = "No devices selected"
            });
            return;
        }

        // Pre-flight checks
        if (!ValidateConfig(config, progress))
            return;

        if (!string.IsNullOrEmpty(config.TpkFolderPath))
        {
            _cachedTpkFiles = Directory.GetFiles(config.TpkFolderPath, "*.tpk");
            if (_cachedTpkFiles.Length == 0)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    Operation = "Validation",
                    Status = ProvisioningStatus.Failed,
                    Message = "No TPK files found in directory"
                });
                return;
            }
            _tpkDistributionIndex = 0;
        }
        else
        {
            _cachedTpkFiles = null;
        }

        // Use semaphore to limit concurrent operations
        var semaphore = new SemaphoreSlim(_config.MaxConcurrentDevices);
        var tasks = new List<Task>();

        foreach (var device in devices)
        {
            await semaphore.WaitAsync(ct);
            tasks.Add(ProvisionSingleDeviceAsync(device, config, progress, ct)
                .ContinueWith(_ => semaphore.Release()));
        }

        await Task.WhenAll(tasks);
    }

    /// <summary>
    /// Provision a single device through full pipeline.
    /// </summary>
    private async Task ProvisionSingleDeviceAsync(
        DeviceInfo device,
        ProvisioningConfig config,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct)
    {
        try
        {
            // 1. Install APKs
            foreach (var apkPath in config.ApkPaths)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Install APK",
                    Status = ProvisioningStatus.InProgress,
                    Message = Path.GetFileName(apkPath)
                });

                var apkResult = await InstallApkAsync(device.Serial, apkPath, progress, ct);
                if (!apkResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Install APK",
                        Status = ProvisioningStatus.Failed,
                        Message = apkResult.Error
                    });
                    return;
                }

                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Install APK",
                    Status = ProvisioningStatus.Success,
                    Message = $"{Path.GetFileName(apkPath)} installed successfully"
                });
            }

            // 2. Push app data
            if (!string.IsNullOrEmpty(config.AppDataPath))
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Push App Data",
                    Status = ProvisioningStatus.InProgress,
                    Message = "Pushing data..."
                });

                var appDataResult = await PushAppDataAsync(device.Serial, config.AppDataPath, progress, ct);
                if (!appDataResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Push App Data",
                        Status = ProvisioningStatus.Failed,
                        Message = appDataResult.Error
                    });
                }
                else
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Push App Data",
                        Status = ProvisioningStatus.Success,
                        Message = "App data pushed successfully"
                    });
                }
            }

            // 3. Push TPK data
            if (!string.IsNullOrEmpty(config.TpkFolderPath))
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Push TPK Data",
                    Status = ProvisioningStatus.InProgress,
                    Message = $"Pushing ({config.TpkMode})..."
                });

                var tpkResult = await PushTpkDataAsync(device.Serial, config.TpkFolderPath, progress, ct);
                if (!tpkResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Push TPK Data",
                        Status = ProvisioningStatus.Failed,
                        Message = tpkResult.Error
                    });
                }
                else
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Push TPK Data",
                        Status = ProvisioningStatus.Success,
                        Message = "TPK data pushed successfully"
                    });
                }
            }

            // 4. Create user
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Create User",
                Status = ProvisioningStatus.InProgress,
                Message = config.EnumeratorUserName
            });

            var userResult = await CreateUserAsync(device.Serial, config.EnumeratorUserName, progress, ct);
            if (!userResult.IsSuccess)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Create User",
                    Status = ProvisioningStatus.Failed,
                    Message = userResult.Error
                });
            }
            else
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Create User",
                    Status = ProvisioningStatus.Success,
                    Message = "User created successfully"
                });
            }

            // 5. Set screen timeout
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Set Screen Timeout",
                Status = ProvisioningStatus.InProgress,
                Message = $"{config.ScreenTimeoutSeconds}s"
            });

            var timeoutResult = await SetScreenTimeoutAsync(device.Serial, config.ScreenTimeoutSeconds, progress, ct);
            if (!timeoutResult.IsSuccess)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Set Screen Timeout",
                    Status = ProvisioningStatus.Failed,
                    Message = timeoutResult.Error
                });
            }
            else
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Set Screen Timeout",
                    Status = ProvisioningStatus.Success,
                    Message = "Screen timeout set"
                });
            }

            // 6. Capture screenshot
            if (config.CaptureScreenshots)
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Capture Screenshot",
                    Status = ProvisioningStatus.InProgress,
                    Message = "Capturing..."
                });

                var screenshotResult = await CaptureScreenshotAsync(device.Serial, config.ScreenshotOutputPath, progress, ct);
                if (!screenshotResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Capture Screenshot",
                        Status = ProvisioningStatus.Failed,
                        Message = screenshotResult.Error
                    });
                }
                else
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Capture Screenshot",
                        Status = ProvisioningStatus.Success,
                        Message = "Screenshot captured"
                    });
                }
            }

            // 7. Set device PIN
            if (!string.IsNullOrEmpty(config.DevicePin))
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Set Device PIN",
                    Status = ProvisioningStatus.InProgress,
                    Message = "Setting PIN..."
                });

                var pinResult = await SetDevicePinAsync(device.Serial, config.DevicePin, progress, ct);
                if (!pinResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Set Device PIN",
                        Status = ProvisioningStatus.Failed,
                        Message = pinResult.Error
                    });
                }
                else
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Set Device PIN",
                        Status = ProvisioningStatus.Success,
                        Message = "PIN set successfully"
                    });
                }
            }

            // 8. Configure APN
            if (config.Apn != null && !string.IsNullOrEmpty(config.Apn.Apn))
            {
                progress?.Report(new ProvisioningUpdate
                {
                    DeviceSerial = device.Serial,
                    Operation = "Configure APN",
                    Status = ProvisioningStatus.InProgress,
                    Message = $"Configuring APN: {config.Apn.Name}"
                });

                var apnResult = await ConfigureApnAsync(device.Serial, config.Apn, progress, ct);
                if (!apnResult.IsSuccess)
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Configure APN",
                        Status = ProvisioningStatus.Failed,
                        Message = apnResult.Error
                    });
                }
                else
                {
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Configure APN",
                        Status = ProvisioningStatus.Success,
                        Message = "APN configured successfully"
                    });
                }
            }

            // Final status
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Provision Complete",
                Status = ProvisioningStatus.Success,
                Message = "Device provisioned successfully"
            });
        }
        catch (OperationCanceledException)
        {
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Provision",
                Status = ProvisioningStatus.Failed,
                Message = "Operation cancelled"
            });
        }
        catch (Exception ex)
        {
            progress?.Report(new ProvisioningUpdate
            {
                DeviceSerial = device.Serial,
                Operation = "Provision",
                Status = ProvisioningStatus.Failed,
                Message = $"Error: {ex.Message}"
            });
        }
    }

    /// <summary>
    /// Validate provisioning configuration.
    /// </summary>
    private bool ValidateConfig(ProvisioningConfig config, IProgress<ProvisioningUpdate> progress)
    {
        if (config.ApkPaths.Count == 0)
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "Validation",
                Status = ProvisioningStatus.Failed,
                Message = "At least one APK file must be specified"
            });
            return false;
        }

        foreach (var apkPath in config.ApkPaths)
        {
            if (string.IsNullOrEmpty(apkPath) || !File.Exists(apkPath))
            {
                progress?.Report(new ProvisioningUpdate
                {
                    Operation = "Validation",
                    Status = ProvisioningStatus.Failed,
                    Message = $"APK file not found: {apkPath}"
                });
                return false;
            }
        }

        if (!string.IsNullOrEmpty(config.AppDataPath) && !Directory.Exists(config.AppDataPath))
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "Validation",
                Status = ProvisioningStatus.Failed,
                Message = "App data folder not found"
            });
            return false;
        }

        if (!string.IsNullOrEmpty(config.TpkFolderPath) && !Directory.Exists(config.TpkFolderPath))
        {
            progress?.Report(new ProvisioningUpdate
            {
                Operation = "Validation",
                Status = ProvisioningStatus.Failed,
                Message = "TPK folder not found"
            });
            return false;
        }

        return true;
    }

    public async Task<AdbResult> InstallApkAsync(string serial, string apkPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} install", $"-r \"{apkPath}\"", ct);
    }

    public async Task<List<AdbResult>> InstallMultipleApksAsync(string serial, List<string> apkPaths, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        var results = new List<AdbResult>();
        foreach (var apkPath in apkPaths)
        {
            var result = await InstallApkAsync(serial, apkPath, progress, ct);
            results.Add(result);
        }
        return results;
    }

    public async Task<AdbResult> PushAppDataAsync(string serial, string appDataPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} push", $"\"{appDataPath}\" /sdcard/Android/data/", ct);
    }

    public async Task<AdbResult> PushTpkDataAsync(string serial, string tpkPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        // Get list of TPK files in folder
        var tpkFiles = _cachedTpkFiles ?? Directory.GetFiles(tpkPath, "*.tpk");
        if (tpkFiles.Length == 0)
        {
            return new AdbResult { ExitCode = 1, Error = "No TPK files found" };
        }

        // Select TPK based on distribution mode
        string selectedTpk = SelectTpkFile(tpkFiles);

        return await _adbService.RunAsync($"-s {serial} push", $"\"{selectedTpk}\" /sdcard/Android/data/", ct);
    }

    /// <summary>
    /// Select TPK file based on distribution strategy.
    /// </summary>
    private string SelectTpkFile(string[] tpkFiles)
    {
        int index = Interlocked.Increment(ref _tpkDistributionIndex) - 1;
        if (index < tpkFiles.Length)
        {
            return tpkFiles[index];
        }
        return tpkFiles[Random.Shared.Next(tpkFiles.Length)];
    }

    public async Task<AdbResult> CreateUserAsync(string serial, string userName, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} shell", $"pm create-user {userName}", ct);
    }

    public async Task<AdbResult> SetScreenTimeoutAsync(string serial, int timeoutSeconds, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        int timeoutMs = timeoutSeconds * 1000;
        return await _adbService.RunAsync($"-s {serial} shell", $"settings put system screen_off_timeout {timeoutMs}", ct);
    }

    public async Task<AdbResult> CaptureScreenshotAsync(string serial, string outputPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        Directory.CreateDirectory(outputPath);
        string filename = $"{serial}_{DateTime.Now:yyyyMMdd_HHmmss}.png";
        string fullPath = Path.Combine(outputPath, filename);

        var captureResult = await _adbService.RunAsync($"-s {serial} shell", "screencap -p /sdcard/screenshot.png", ct);
        if (!captureResult.IsSuccess)
            return captureResult;

        return await _adbService.RunAsync($"-s {serial} pull", $"/sdcard/screenshot.png \"{fullPath}\"", ct);
    }

    public async Task<AdbResult> SetDevicePinAsync(string serial, string pin, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} shell", $"locksettings set-pin {pin}", ct);
    }

    public async Task<AdbResult> ConfigureApnAsync(string serial, ApnConfig apn, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default)
    {
        var apnArgs = $"content insert --uri content://telephony/carriers " +
                      $"--bind name:s:\"{apn.Name}\" " +
                      $"--bind apn:s:\"{apn.Apn}\" " +
                      $"--bind mcc:s:\"{apn.Mcc}\" " +
                      $"--bind mnc:s:\"{apn.Mnc}\" " +
                      $"--bind type:s:\"{apn.Type}\" " +
                      $"--bind current:i:1";
        return await _adbService.RunAsync($"-s {serial} shell", apnArgs, ct);
    }
}
