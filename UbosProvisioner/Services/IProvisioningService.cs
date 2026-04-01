using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public interface IProvisioningService
{
    /// <summary>
    /// Execute full provisioning pipeline on selected devices.
    /// </summary>
    Task ProvisionDevicesAsync(
        List<DeviceInfo> devices,
        ProvisioningConfig config,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default);

    /// <summary>
    /// Install APK on a device.
    /// </summary>
    Task<AdbResult> InstallApkAsync(string serial, string apkPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Install multiple APKs on a device sequentially.
    /// </summary>
    Task<List<AdbResult>> InstallMultipleApksAsync(string serial, List<string> apkPaths, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Push app data folder to device.
    /// </summary>
    Task<AdbResult> PushAppDataAsync(string serial, string appDataPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Push TPK folder to device (with distribution logic).
    /// </summary>
    Task<AdbResult> PushTpkDataAsync(string serial, string tpkPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Create user account on device.
    /// </summary>
    Task<AdbResult> CreateUserAsync(string serial, string userName, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Set screen timeout on device.
    /// </summary>
    Task<AdbResult> SetScreenTimeoutAsync(string serial, int timeoutSeconds, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Capture screenshot for QC.
    /// </summary>
    Task<AdbResult> CaptureScreenshotAsync(string serial, string outputPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Set device PIN (screen lock).
    /// </summary>
    Task<AdbResult> SetDevicePinAsync(string serial, string pin, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Configure APN (Access Point Name) for mobile data.
    /// </summary>
    Task<AdbResult> ConfigureApnAsync(string serial, ApnConfig apn, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);
}
