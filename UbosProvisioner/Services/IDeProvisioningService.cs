using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public interface IDeProvisioningService
{
    /// <summary>
    /// Execute full de-provisioning pipeline on selected devices.
    /// </summary>
    Task DeProvisionDevicesAsync(
        List<DeviceInfo> devices,
        string outputDataPath,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default);

    /// <summary>
    /// Pull sensitive data from device.
    /// </summary>
    Task<AdbResult> PullDataAsync(string serial, string outputPath, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);

    /// <summary>
    /// Factory reset device (wipe data).
    /// </summary>
    Task<AdbResult> FactoryResetAsync(string serial, IProgress<ProvisioningUpdate> progress, CancellationToken ct = default);
}
