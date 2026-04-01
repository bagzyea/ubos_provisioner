using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class AdbService : IAdbService
{
    private readonly string _adbPath;
    private CancellationTokenSource? _pollingCts;
    private Task? _pollingTask;
    private Action<List<DeviceInfo>>? _onDevicesUpdated;
    private int _pollIntervalMs = 5000;

    public AdbService(AppSettings config)
    {
        var basePath = AppDomain.CurrentDomain.BaseDirectory;
        _adbPath = Path.Combine(basePath, config.PlatformToolsPath, "adb.exe");

        if (!File.Exists(_adbPath))
        {
            Debug.WriteLine($"Warning: ADB not found at {_adbPath}. Device operations will fail.");
            // Don't throw - allow app to start anyway
        }
    }

    /// <summary>
    /// Run a raw ADB command synchronously.
    /// </summary>
    public async Task<AdbResult> RunAsync(string command, string args = "", CancellationToken ct = default)
    {
        if (!File.Exists(_adbPath))
        {
            return new AdbResult
            {
                ExitCode = -1,
                Error = $"ADB executable not found at {_adbPath}"
            };
        }

        var fullArgs = string.IsNullOrEmpty(args) ? command : $"{command} {args}";

        var psi = new ProcessStartInfo
        {
            FileName = _adbPath,
            Arguments = fullArgs,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8
        };

        using (var process = Process.Start(psi))
        {
            if (process == null)
                return new AdbResult { ExitCode = -1, Error = "Failed to start process" };

            var outputTask = process.StandardOutput.ReadToEndAsync();
            var errorTask = process.StandardError.ReadToEndAsync();

            try
            {
                using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeoutCts.CancelAfter(30000); // 30-second timeout
                await process.WaitForExitAsync(timeoutCts.Token);
            }
            catch (OperationCanceledException)
            {
                try { process.Kill(); } catch { }
                return new AdbResult { ExitCode = -1, Error = "ADB process timed out or was cancelled." };
            }

            var output = await outputTask;
            var error = await errorTask;

            return new AdbResult
            {
                ExitCode = process.ExitCode,
                Output = output,
                Error = error
            };
        }
    }

    /// <summary>
    /// Parse "adb devices" output into DeviceInfo list.
    /// </summary>
    public async Task<List<DeviceInfo>> GetConnectedDevicesAsync(CancellationToken ct = default)
    {
        var result = await RunAsync("devices", "", ct);
        var devices = new List<DeviceInfo>();

        if (!result.IsSuccess)
            return devices;

        var lines = result.Output.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);

        foreach (var line in lines.Skip(1)) // Skip "List of attached devices"
        {
            var trimmed = line.Trim();
            if (string.IsNullOrEmpty(trimmed))
                continue;

            var parts = trimmed.Split(new[] { '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2)
            {
                string serial = parts[0];
                string state = parts[1];

                // Only include "device" (connected) or "offline" states
                if (state == "device" || state == "offline")
                {
                    devices.Add(new DeviceInfo
                    {
                        Serial = serial,
                        ConnectionState = state,
                        Model = await GetDeviceModelAsync(serial),
                        BatteryLevel = await GetBatteryLevelAsync(serial),
                        StorageFree = await GetStorageFreeAsync(serial)
                    });
                }
            }
        }

        return devices;
    }

    /// <summary>
    /// Get device model name via "adb shell getprop ro.product.model".
    /// </summary>
    private async Task<string> GetDeviceModelAsync(string serial)
    {
        var result = await RunAsync($"-s {serial} shell", "getprop ro.product.model");
        return result.IsSuccess ? result.Output.Trim() : "Unknown";
    }

    /// <summary>
    /// Get battery level via "adb -s serial shell dumpsys battery".
    /// </summary>
    private async Task<int> GetBatteryLevelAsync(string serial)
    {
        var result = await RunAsync($"-s {serial} shell", "dumpsys battery");
        if (!result.IsSuccess)
            return -1;

        var match = Regex.Match(result.Output, @"level:\s*(\d+)");
        return match.Success ? int.Parse(match.Groups[1].Value) : -1;
    }

    /// <summary>
    /// Get free storage on /sdcard via "adb -s serial shell df /sdcard".
    /// </summary>
    private async Task<long> GetStorageFreeAsync(string serial)
    {
        var result = await RunAsync($"-s {serial} shell", "df /sdcard");
        if (!result.IsSuccess)
            return -1;

        var lines = result.Output.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
        if (lines.Length < 2)
            return -1;

        var parts = lines[1].Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 4 && long.TryParse(parts[3], out long free) ? free : -1;
    }

    /// <summary>
    /// Start background polling of devices every N milliseconds.
    /// </summary>
    public void StartDevicePolling(Action<List<DeviceInfo>> onDevicesUpdated, int intervalMs = 5000)
    {
        if (_pollingTask != null && !_pollingTask.IsCompleted)
            return; // Already polling

        _onDevicesUpdated = onDevicesUpdated;
        _pollIntervalMs = intervalMs;
        _pollingCts = new CancellationTokenSource();

        _pollingTask = Task.Run(async () =>
        {
            while (!_pollingCts.Token.IsCancellationRequested)
            {
                try
                {
                    var devices = await GetConnectedDevicesAsync(_pollingCts.Token);
                    _onDevicesUpdated?.Invoke(devices);
                    await Task.Delay(_pollIntervalMs, _pollingCts.Token);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Device polling error: {ex.Message}");
                    await Task.Delay(_pollIntervalMs, _pollingCts.Token);
                }
            }
        });
    }

    /// <summary>
    /// Stop background polling.
    /// </summary>
    public void StopDevicePolling()
    {
        if (_pollingCts != null)
        {
            _pollingCts.Cancel();
            _pollingTask?.Wait(5000);
        }
    }
}
