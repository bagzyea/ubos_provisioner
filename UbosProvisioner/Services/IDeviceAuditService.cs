using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public interface IDeviceAuditService
{
    /// <summary>
    /// Audit a device for lock status, MDM enrollment, FRP state.
    /// </summary>
    Task<DeviceAuditReport> AuditDeviceAsync(string serial, CancellationToken ct = default);

    /// <summary>
    /// Attempt to clear screen lock with known PIN.
    /// </summary>
    Task<AdbResult> ClearLockWithPinAsync(string serial, string pin, CancellationToken ct = default);

    /// <summary>
    /// Reboot device to recovery mode for manual factory reset.
    /// </summary>
    Task<AdbResult> RebootToRecoveryAsync(string serial, CancellationToken ct = default);

    /// <summary>
    /// Audit multiple devices in parallel.
    /// </summary>
    Task<List<DeviceAuditReport>> AuditMultipleDevicesAsync(
        List<DeviceInfo> devices,
        IProgress<ProvisioningUpdate> progress,
        CancellationToken ct = default);
}
