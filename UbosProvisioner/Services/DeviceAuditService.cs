using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class DeviceAuditService : IDeviceAuditService
{
    private readonly IAdbService _adbService;
    private readonly AppSettings _config;

    public DeviceAuditService(IAdbService adbService, AppSettings config)
    {
        _adbService = adbService;
        _config = config;
    }

    /// <summary>
    /// Comprehensive device audit: lock status, MDM, FRP, battery, storage.
    /// </summary>
    public async Task<DeviceAuditReport> AuditDeviceAsync(string serial, CancellationToken ct = default)
    {
        var report = new DeviceAuditReport { Serial = serial };

        try
        {
            // Get model
            var modelResult = await _adbService.RunAsync($"-s {serial} shell", "getprop ro.product.model", ct);
            report.Model = modelResult.IsSuccess ? modelResult.Output.Trim() : "Unknown";

            // Check lock status
            var lockResult = await _adbService.RunAsync($"-s {serial} shell", "locksettings get-disabled", ct);
            report.IsScreenLocked = !lockResult.IsSuccess || lockResult.Output.Contains("false");

            // Check device admin / MDM
            var adminResult = await _adbService.RunAsync($"-s {serial} shell", "dumpsys device_policy", ct);
            report.HasDeviceAdmin = adminResult.Output.Contains("ComponentInfo") || adminResult.Output.Contains("Active");
            ExtractDeviceAdminPackages(adminResult.Output, report);

            // Check FRP status
            var frpResult = await _adbService.RunAsync($"-s {serial} shell", "settings get secure user_setup_complete", ct);
            report.IsFrpActive = frpResult.IsSuccess && frpResult.Output.Contains("1");

            // Get battery and storage
            report.BatteryLevel = await GetBatteryLevelAsync(serial);
            report.StorageFree = await GetStorageFreeAsync(serial);

            // Generate remediation instructions
            GenerateRemediationInstructions(report);
        }
        catch (Exception ex)
        {
            report.RemediationInstructions = $"Audit error: {ex.Message}";
        }

        return report;
    }

    /// <summary>
    /// Extract device admin packages from dumpsys output.
    /// </summary>
    private void ExtractDeviceAdminPackages(string dumpsysOutput, DeviceAuditReport report)
    {
        var lines = dumpsysOutput.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
        var packages = new List<string>();

        foreach (var line in lines)
        {
            if (line.Contains("ComponentInfo") && line.Contains("package="))
            {
                var match = Regex.Match(line, @"package=([^\s]+)");
                if (match.Success)
                {
                    packages.Add(match.Groups[1].Value);
                }
            }
        }

        report.DeviceAdminPackages = string.Join(", ", packages);
    }

    /// <summary>
    /// Get device battery level.
    /// </summary>
    private async Task<int> GetBatteryLevelAsync(string serial)
    {
        var result = await _adbService.RunAsync($"-s {serial} shell", "dumpsys battery");
        if (!result.IsSuccess)
            return -1;

        var match = Regex.Match(result.Output, @"level:\s*(\d+)");
        return match.Success ? int.Parse(match.Groups[1].Value) : -1;
    }

    /// <summary>
    /// Get device storage free.
    /// </summary>
    private async Task<long> GetStorageFreeAsync(string serial)
    {
        var result = await _adbService.RunAsync($"-s {serial} shell", "df /sdcard");
        if (!result.IsSuccess)
            return -1;

        var lines = result.Output.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
        if (lines.Length < 2)
            return -1;

        var parts = lines[1].Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 4 && long.TryParse(parts[3], out long free) ? free : -1;
    }

    /// <summary>
    /// Generate actionable remediation instructions based on audit findings.
    /// </summary>
    private void GenerateRemediationInstructions(DeviceAuditReport report)
    {
        var instructions = new System.Text.StringBuilder();

        if (!report.IsScreenLocked)
        {
            instructions.AppendLine("✓ Screen is not locked.");
        }
        else
        {
            instructions.AppendLine("⚠ Screen Lock Detected:");
            instructions.AppendLine("  • If you know the PIN, you can clear it via ADB.");
            instructions.AppendLine("  • Otherwise, factory reset is required (see below).");
        }

        if (report.HasDeviceAdmin)
        {
            instructions.AppendLine();
            instructions.AppendLine("⚠ Device Admin / MDM Detected:");
            if (!string.IsNullOrEmpty(report.DeviceAdminPackages))
            {
                instructions.AppendLine($"  • Enrolled: {report.DeviceAdminPackages}");
            }
            instructions.AppendLine("  • Cannot be removed via ADB.");
            instructions.AppendLine("  • Contact your IT admin to unenroll:");
            instructions.AppendLine("    - Google Workspace: admin.google.com → Devices → Wipe");
            instructions.AppendLine("    - Microsoft Intune: portal.azure.com → Device management");
            instructions.AppendLine("    - Samsung Knox: Knox Matrix console");
        }

        if (report.IsFrpActive)
        {
            instructions.AppendLine();
            instructions.AppendLine("⚠ FRP (Factory Reset Protection) Active:");
            instructions.AppendLine("  • A Google or MDM account is signed in.");
            instructions.AppendLine("  • After factory reset, this account must sign in again.");
            instructions.AppendLine("  • If you don't have credentials, contact the account owner.");
        }

        if (report.BatteryLevel < 20)
        {
            instructions.AppendLine();
            instructions.AppendLine($"⚠ Low Battery ({report.BatteryLevel}%):");
            instructions.AppendLine("  • Charge device before performing any operations.");
        }

        if (string.IsNullOrEmpty(report.DeviceAdminPackages) && report.IsScreenLocked && !report.IsFrpActive)
        {
            instructions.AppendLine();
            instructions.AppendLine("✓ Good News: Device can likely be recovered via factory reset:");
            instructions.AppendLine("  • Use 'Reboot to Recovery' option below.");
            instructions.AppendLine("  • Complete the manual wipe on the device.");
        }

        report.RemediationInstructions = instructions.ToString();
    }

    /// <summary>
    /// Attempt to clear screen lock with known PIN.
    /// </summary>
    public async Task<AdbResult> ClearLockWithPinAsync(string serial, string pin, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} shell", $"locksettings clear --old {pin}", ct);
    }

    /// <summary>
    /// Reboot device to recovery mode.
    /// </summary>
    public async Task<AdbResult> RebootToRecoveryAsync(string serial, CancellationToken ct = default)
    {
        return await _adbService.RunAsync($"-s {serial} reboot", "recovery", ct);
    }

    /// <summary>
    /// Audit multiple devices in parallel.
    /// </summary>
    public async Task<List<DeviceAuditReport>> AuditMultipleDevicesAsync(
        List<DeviceInfo> devices,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default)
    {
        var semaphore = new System.Threading.SemaphoreSlim(_config.MaxConcurrentDevices);
        var tasks = new List<Task<DeviceAuditReport>>();

        foreach (var device in devices)
        {
            await semaphore.WaitAsync(ct);

            tasks.Add(AuditDeviceAsync(device.Serial, ct)
                .ContinueWith(async t =>
                {
                    semaphore.Release();
                    progress?.Report(new ProvisioningUpdate
                    {
                        DeviceSerial = device.Serial,
                        Operation = "Audit",
                        Status = ProvisioningStatus.Success,
                        Message = "Device audit complete"
                    });
                    return await t;
                }).Unwrap());
        }

        var results = await Task.WhenAll(tasks);
        return results.ToList();
    }
}
